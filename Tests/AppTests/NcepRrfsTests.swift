import Foundation
import Testing
import Logging
import OmFileIO
@preconcurrency import SwiftEccodes
@testable import App

@Suite struct NcepRrfsTests {
    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/ncep-rrfs")
    }

    private func forecastHour(filename: String) throws -> Int {
        try #require(filename.split(separator: ".").first(where: { $0.hasPrefix("f") && Int($0.dropFirst()) != nil }).flatMap { Int($0.dropFirst()) })
    }

    private func records(_ filename: String, domain: NcepRrfsDomain, pressure: Bool = false) throws -> [NcepRrfsDownloadVariable] {
        let index = try String(contentsOf: fixtureDirectory.appendingPathComponent(filename), encoding: .utf8)
        let variables = domain.downloadVariables(forecastHour: try forecastHour(filename: filename), pressureFile: pressure)
        let decoded = try Curl.decodeGribIndices(indices: [index], variables: variables, errorOnMissing: true, logger: Logger(label: filename))
        return try #require(decoded.first).matches
    }

    @Test func seamlessForecastMapping() throws {
        let model = try #require(MultiDomains(rawValue: "ncep_rrfs_seamless"))
        for include15Min in [false, true] {
            guard case .multipleWithPrecipitationProbability(let sources, let probability) = model.getDomainAndVariable(include15Min: include15Min) else {
                Issue.record("Expected RRFS seamless domain mapping")
                return
            }
            #expect(probability.domainRegistry == .ncep_rrfs_conus_ensemble)
            let expected: [DomainRegistry] = [.ncep_gefs05, .ncep_gfs025, .ncep_rrfs_conus]
                + (include15Min ? [.ncep_rrfs_conus_15min] : [])
            #expect(sources.map { $0.0.domainRegistry } == expected)
            #expect(ObjectIdentifier(sources[0].1) == ObjectIdentifier(Gefs05Variable.self))
            #expect(ObjectIdentifier(sources[1].1) == ObjectIdentifier(Gfs025Variable.self))
            #expect(ObjectIdentifier(sources[2].1) == ObjectIdentifier(NcepRrfsVariable.self))
            if include15Min { #expect(ObjectIdentifier(sources[3].1) == ObjectIdentifier(NcepRrfs15MinVariable.self)) }
        }
        #expect(model.genericDomain == nil)
        #expect(model.countEnsembleMember == 1)
        #expect(model.flatBufferModel == .undefined)
    }

    @Test func individualForecastMappings() throws {
        let expected: [(NcepRrfsDomain, any GenericVariable.Type)] = [
            (.ncep_rrfs_conus, NcepRrfsVariable.self),
            (.ncep_rrfs_conus_15min, NcepRrfs15MinVariable.self),
            (.ncep_rrfs_conus_ensemble, NcepRrfsEnsembleVariable.self)
        ]
        for (domain, variableType) in expected {
            let model = try #require(MultiDomains(rawValue: domain.rawValue))
            for include15Min in [false, true] {
                guard case .singleWithPrecipitationProbability(let source, let variables, let probability) = model.getDomainAndVariable(include15Min: include15Min) else {
                    Issue.record("Expected an individual RRFS reader")
                    return
                }
                #expect(source.domainRegistry == domain.domainRegistry)
                #expect(probability.domainRegistry == .ncep_rrfs_conus_ensemble)
                #expect(ObjectIdentifier(variables) == ObjectIdentifier(variableType))
            }
            #expect(model.genericDomain?.domainRegistry == domain.domainRegistry)
            #expect(model.countEnsembleMember == domain.countEnsembleMember)
            #expect(model.flatBufferModel == .undefined)
        }
    }

    @Test func ensemblePrecipitationProbabilityOutput() async throws {
        // The temporary OM writer uses the configured data directory even with
        // storeOnDisk disabled. A clean CI checkout has not created it yet.
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        let domain = ProbabilityTestDomain()
        let run = Timestamp(2026, 9, 20)
        let storage = VariablePerMemberStorage<NcepRrfsEnsembleSurfaceVariable>()
        let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: run.add(hours: 1), storeOnDisk: false, realm: nil, logger: Logger(label: "rrfs-probability-test"))
        // Zero, one, three and all five members reaching the 0.1 mm/hour threshold.
        for member in 0..<5 {
            let values: [Float] = [0.09, member == 0 ? 0.1 : 0, member < 3 ? 0.1 : 0, 1]
            await storage.set(variable: .precipitation, timestamp: run.add(hours: 1), member: member,
                              data: Array2D(data: values, nx: 4, ny: 1))
        }
        try await storage.calculatePrecipitationProbability(precipitationVariable: .precipitation, dtHoursOfCurrentStep: 1, writer: writer)
        let handles = try await writer.finalise()
        #expect(handles.count == 1)
        let handle = try #require(handles.first)
        #expect(handle.variable.rawValue == "precipitation_probability")
        #expect(handle.member == 0)
        let probability = try await handle.reader.read(range: [0..<1, 0..<4])
        #expect(probability == [0, 20, 60, 100])
    }

    @Test func domainSchedulesAndMemberUrls() {
        let run = Timestamp(2026, 9, 20)
        #expect(NcepRrfsDomain.ncep_rrfs_conus.forecastHours == 0...84)
        #expect(NcepRrfsDomain.ncep_rrfs_conus_15min.forecastHours == 1...18)
        #expect(NcepRrfsDomain.ncep_rrfs_conus_ensemble.forecastHours == 0...60)
        #expect(NcepRrfsDomain.ncep_rrfs_conus_15min.dtSeconds == 900)
        #expect(NcepRrfsDomain.ncep_rrfs_conus_ensemble.countEnsembleMember == 5)
        #expect(NcepRrfsDomain.ncep_rrfs_conus.lastRun(now: run.add(hours: 3).add(44 * 60)) == run.add(hours: -6))
        #expect(NcepRrfsDomain.ncep_rrfs_conus.lastRun(now: run.add(hours: 3).add(45 * 60)) == run)
        #expect(NcepRrfsDomain.ncep_rrfs_conus_15min.lastRun(now: run.add(hours: 4).add(45 * 60)) == run.add(hours: 1))
        for member in 0..<5 {
            let urls = NcepRrfsDomain.ncep_rrfs_conus_ensemble.gribUrls(run: run, forecastHour: 60, member: member, server: "https://example.com/")
            #expect(urls[0] == "https://example.com/rrfsens.20260920/00/m00\(member + 1)/rrfs.t00z.m00\(member + 1).2dfldnomads.3km.f060.conus.grib2")
        }
        for domain in NcepRrfsDomain.allCases {
            #expect(domain.domainRegistry.getDomain()?.domainRegistry == domain.domainRegistry)
        }
    }

    @Test func exactGridAndRotation() {
        let grid = NcepRrfsDomain.ncep_rrfs_conus.projectedGrid
        #expect(grid.nx == 1799 && grid.ny == 1059)
        #expect(grid.dx == 3000 && grid.dy == 3000)
        let origin = grid.getCoordinates(gridpoint: 0)
        #expect(abs(origin.latitude - 21.1381) < 0.001)
        #expect(abs(origin.longitude + 122.72) < 0.001)
        let north = grid.getTrueNorthDirection()
        #expect(north.allSatisfy { $0.isFinite })
        #expect(abs(north[0]) > 10)
    }

    @Test func hourlyInventorySelectionAndCatalogCoverage() throws {
        let fields = try records("rrfs.t00z.2dfld.3km.f001.conus.grib2.idx", domain: .ncep_rrfs_conus)
        #expect(fields.filter { $0.variable.rawValue == "shortwave_radiation" }.map { $0.interval.type } == ["avg"])
        #expect(fields.filter { $0.variable.rawValue == "cloud_cover" }.map { $0.interval.type } == ["instant"])
        let names = Set(fields.map { $0.variable.rawValue })
        for required in ["cape", "convective_inhibition", "boundary_layer_height", "wind_speed_4572m", "wind_speed_320m", "soil_temperature_0cm", "soil_moisture_300cm"] {
            #expect(names.contains(required))
        }
        for variable in NcepRrfsSurfaceVariable.allCases {
            let input = variable.rawValue
            #expect(names.contains(input), "Missing inventory field for \(variable)")
        }
    }

    @Test func subhourlyMinutesAndAccumulationRanges() throws {
        let first = try records("rrfs.t00z.2dfld.3km.subh.f001.conus.grib2.idx", domain: .ncep_rrfs_conus_15min)
        let second = try records("rrfs.t00z.2dfld.3km.subh.f002.conus.grib2.idx", domain: .ncep_rrfs_conus_15min)
        let precipitation = (first + second).filter { $0.variable.rawValue == "precipitation" }
        #expect(precipitation.map(\.minute) == [15, 30, 45, 60, 75, 90, 105, 120])
        #expect(precipitation.allSatisfy { $0.interval.start == 0 && $0.interval.type == "accum" })
        #expect(first.filter { $0.variable.isDewpoint }.count == 4)
        #expect(first.filter { $0.variable.rawValue == "shortwave_radiation" }.allSatisfy { $0.interval.type == "instant" })
        #expect(first.allSatisfy { !$0.variable.rawValue.contains("hPa") })
    }

    @Test func ensembleCatalogMatchesReducedInventory() throws {
        let fields = try records("rrfs.t00z.m001.2dfldnomads.3km.f001.conus.grib2.idx", domain: .ncep_rrfs_conus_ensemble)
        let names = Set(fields.map { $0.variable.rawValue })
        for variable in NcepRrfsEnsembleSurfaceVariable.allCases {
            #expect(names.contains(variable.rawValue))
        }
        #expect(NcepRrfsEnsembleSurfaceVariable(rawValue: "boundary_layer_height") == nil)
        #expect(NcepRrfsEnsembleSurfaceVariable(rawValue: "wind_speed_4572m") == nil)
    }

    @Test func pressureCatalogsMatchInventories() throws {
        for (filename, domain, variables) in [
            ("rrfs.t00z.prslev.3km.f001.conus.grib2.idx", NcepRrfsDomain.ncep_rrfs_conus, NcepRrfsConusPressureVariable.allVariables.map(\.rawValue)),
            ("rrfs.t00z.m001.prslevnomads.3km.f001.conus.grib2.idx", NcepRrfsDomain.ncep_rrfs_conus_ensemble, NcepRrfsEnsemblePressureVariable.allVariables.map(\.rawValue))
        ] {
            let fields = try records(filename, domain: domain, pressure: true)
            let names = Set(fields.map { $0.variable.rawValue })
            for variable in variables {
                #expect(names.contains(variable))
            }
            #expect(fields.allSatisfy { $0.variable.rawValue.hasSuffix("hPa") })
        }
        #expect(NcepRrfsEnsemblePressureVariable(rawValue: "temperature_50hPa") == nil)
        #expect(NcepRrfsConusPressureVariable(rawValue: "temperature_500hPa_extra") == nil)
    }

    @Test func analysisInventoriesAndMissingWindComponent() throws {
        for file in ["rrfs.t00z.2dfld.3km.f000.conus.grib2.idx", "rrfs.t00z.prslev.3km.f000.conus.grib2.idx", "rrfs.t00z.m001.prslevnomads.3km.f000.conus.grib2.idx"] {
            let domain: NcepRrfsDomain = file.contains("m001") ? .ncep_rrfs_conus_ensemble : .ncep_rrfs_conus
            let selected = try records(file, domain: domain, pressure: file.contains("prslev"))
            #expect(!selected.isEmpty)
            #expect(selected.allSatisfy { $0.minute == 0 && $0.interval.type == "instant" })
        }
        let wind = [NcepRrfsSurfaceVariable.wind_speed_10m, .wind_direction_10m]
            .map { NcepRrfsDownloadVariable(variable: $0, minute: 0) }
        for index in ["", "1:0:d=2026092000:UGRD:10 m above ground:anl:"] {
            #expect(throws: CurlError.self) {
                try Curl.decodeGribIndices(indices: [index], variables: wind, errorOnMissing: true, logger: Logger(label: "missing-wind-test"))
            }
        }
    }

    @Test func indexedSelectionPreservesTimesAndExcludesUnusedFields() throws {
        let lines = [
            "1:0:d=2026092000:TMP:2 m above ground:15 min fcst:",
            "2:100:d=2026092000:TMP:2 m above ground:30 min fcst:",
            "3:200:d=2026092000:TMP:2 m above ground:45 min fcst:",
            "4:300:d=2026092000:TMP:2 m above ground:1 hour fcst:",
            "5:400:d=2026092000:HGT:surface:15 min fcst:",
            "6:500:d=2026092000:REFC:entire atmosphere (considered as a single layer):15 min fcst:",
            "7:600:d=2026092000:TMP:2 m above ground:15 min fcst:"
        ]
        let variables = NcepRrfsDomain.ncep_rrfs_conus_15min.downloadVariables(forecastHour: 1, pressureFile: false)
            .filter { $0.variable.rawValue == "temperature_2m" }
        #expect(variables.map { $0.minute } == [15, 30, 45, 60])
        #expect(Set(variables.compactMap(\.gribIndexName)).count == 4)
        for (i, line) in lines.enumerated() {
            let matches = variables.filter { line.hasSuffix($0.gribIndexName!) }
            #expect(matches.count == (i < 4 || i == 6 ? 1 : 0))
        }
        let decoded = try Curl.decodeGribIndices(indices: [lines.joined(separator: "\n")], variables: variables,
                                                errorOnMissing: true, logger: Logger(label: "rrfs-index-test"))
        #expect(decoded.count == 1)
        #expect(decoded[0].range == "0-399")
        #expect(decoded[0].minSize == 400)
        #expect(decoded[0].matches.map { $0.minute } == [15, 30, 45, 60])
        #expect(throws: CurlError.self) {
            try Curl.decodeGribIndices(indices: [lines[0]], variables: variables,
                                       errorOnMissing: true, logger: Logger(label: "rrfs-index-test"))
        }
    }

    @Test func protocolSelectorsMatchAvailableInventories() throws {
        let files = try FileManager.default.contentsOfDirectory(at: fixtureDirectory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "idx" }
        #expect(files.count == 9)
        for file in files {
            let name = file.lastPathComponent
            let domain: NcepRrfsDomain = name.contains("m001") ? .ncep_rrfs_conus_ensemble : name.contains("subh") ? .ncep_rrfs_conus_15min : .ncep_rrfs_conus
            let hour = try forecastHour(filename: name)
            let variables = domain.downloadVariables(forecastHour: hour, pressureFile: name.contains("prslev"))
            let index = try String(contentsOf: file, encoding: .utf8)
            let decoded = try Curl.decodeGribIndices(indices: [index], variables: variables, errorOnMissing: true, logger: Logger(label: name))
            #expect(decoded[0].matches.count == variables.count)
        }
    }

    @Test func productSpecificSnowfallInputs() throws {
        for domain in NcepRrfsDomain.allCases {
            let inputs = domain.downloadVariables(forecastHour: 3, pressureFile: false)
                .filter { $0.variable.rawValue == "snowfall_water_equivalent" }
            #expect(inputs.count == (domain == .ncep_rrfs_conus_15min ? 4 : 1))
            for input in inputs {
                let record = input
                if domain == .ncep_rrfs_conus_ensemble {
                    #expect(record.variable.gribInput.parameter == "CPOFP")
                    #expect(record.variable.isFrozenPrecipitationPercent)
                    #expect(record.interval.type == "instant")
                } else {
                    #expect(record.variable.gribInput.parameter == "TSNOWP")
                    #expect(record.variable.rawValue == "snowfall_water_equivalent")
                    #expect(record.interval.start == 0 && record.interval.type == "accum")
                    var data: [Float] = [2.5]
                    record.variable.convertUnits(data: &data)
                    #expect(data == [2.5]) // kg/m² is already mm water equivalent.
                }
            }
        }
    }

    @Test func productSpecificSolarIntervals() throws {
        for domain in NcepRrfsDomain.allCases {
            let inputs = domain.downloadVariables(forecastHour: 3, pressureFile: false)
                .filter { $0.variable.isSolarRadiation }
            #expect(!inputs.isEmpty)
            for input in inputs {
                let record = input
                let usesAverage = domain != .ncep_rrfs_conus_15min && record.variable.gribInput.parameter == "DSWRF"
                #expect(record.interval.type == (usesAverage ? "avg" : "instant"))
                #expect(record.requiresSolarBackwardsConversion == !usesAverage)
                #expect(record.interval.start == record.minute - (usesAverage ? 60 : 0))
            }
        }
        for domain in [NcepRrfsDomain.ncep_rrfs_conus, .ncep_rrfs_conus_ensemble] {
            let input = NcepRrfsDownloadVariable(variable: domain == .ncep_rrfs_conus
                ? NcepRrfsSurfaceVariable.shortwave_radiation as any NcepRrfsVariableDownloadable
                : NcepRrfsEnsembleSurfaceVariable.shortwave_radiation, minute: 180)
            let instant = "1:0:d=2026092000:DSWRF:surface:3 hour fcst:"
            let runningAverage = "2:100:d=2026092000:DSWRF:surface:0-3 hour ave fcst:"
            let lastHour = "3:200:d=2026092000:DSWRF:surface:2-3 hour ave fcst:"
            let selected = try Curl.decodeGribIndices(indices: [[instant, runningAverage, lastHour].joined(separator: "\n")], variables: [input], errorOnMissing: true, logger: Logger(label: "solar-test"))
            #expect(selected[0].matches.count == 1)
            #expect(selected[0].range == "200-")
            // An absent required hourly mean must not silently use a running mean.
            #expect(throws: CurlError.self) {
                try Curl.decodeGribIndices(indices: [runningAverage], variables: [input], errorOnMissing: true, logger: Logger(label: "solar-test"))
            }
        }
    }

    @Test func conversionsAndMetadata() {
        let conversions: [(any NcepRrfsVariableDownloadable, Float, Float)] = [
            (NcepRrfsSurfaceVariable.temperature_2m, 273.15, 0),
            (NcepRrfsSurfaceVariable.pressure_msl, 101325, 1013.25),
            (NcepRrfsSurfaceVariable.snowfall, 0.02, 2),
            (NcepRrfsSurfaceVariable.convective_inhibition, -150, 150),
            (NcepRrfs15MinVariable.relative_humidity_2m, 273.15, 0), // DPT input
            (NcepRrfsEnsembleSurfaceVariable.relative_humidity_2m, 75, 75),
            (NcepRrfsConusPressureVariable(variable: .temperature, level: 500), 273.15, 0)
        ]
        for (variable, raw, expected) in conversions {
            var values = [raw]
            variable.convertUnits(data: &values)
            #expect(abs(values[0] - expected) < 0.001)
        }
        let variables: [any GenericVariable] = NcepRrfsSurfaceVariable.allCases.map { $0 as any GenericVariable }
            + NcepRrfs15MinVariable.allCases.map { $0 as any GenericVariable }
            + NcepRrfsEnsembleSurfaceVariable.allCases.map { $0 as any GenericVariable }
            + NcepRrfsConusPressureVariable.allVariables.map { $0 as any GenericVariable }
        for variable in variables {
            #expect(variable.scalefactor > 0)
            _ = variable.unit
            _ = variable.interpolation
        }
        #expect(NcepRrfsSurfaceVariable.wind_direction_4572m.unit == .degreeDirection)
    }

    @Test func chronologicalDeaccumulationAcrossHourAndMemberBoundaries() async throws {
        let records = try (1...2).flatMap { hour in
            try self.records("rrfs.t00z.2dfld.3km.subh.f00\(hour).conus.grib2.idx", domain: .ncep_rrfs_conus_15min)
        }
        let deaverager = GribDeaverager()
        for variable in ["precipitation", "snowfall_water_equivalent"] {
            let accumulated = records.filter { $0.variable.rawValue == variable }
            #expect(accumulated.count == 8)
            for (i, record) in accumulated.enumerated() {
                for member in 0..<2 {
                    let amount = Float(member + 1)
                    var array = Array2D(data: [Float(i + 1) * amount], nx: 1, ny: 1)
                    let keep = await deaverager.deaccumulateIfRequired(variable: record.variable.rawValue, member: member, stepType: record.interval.type,
                        stepRange: "\(record.interval.start)-\(record.minute)", array2d: &array)
                    #expect(keep)
                    #expect(array.data == [amount])
                }
            }
        }
    }
    /// Optional verification against an actual NOAA file, without checking large GRIBs into git.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RRFS_TEST_GRIB"] != nil))
    func realGribInventoryAndDecoding() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["RRFS_TEST_GRIB"])
        let domain = try #require(NcepRrfsDomain(rawValue: ProcessInfo.processInfo.environment["RRFS_TEST_DOMAIN"] ?? "ncep_rrfs_conus_ensemble"))
        let index = try String(contentsOfFile: path + ".idx", encoding: .utf8)
        let inputs = domain.downloadVariables(forecastHour: try forecastHour(filename: URL(fileURLWithPath: path).lastPathComponent), pressureFile: path.contains("prslev"))
        let selection = try Curl.decodeGribIndices(indices: [index], variables: inputs, errorOnMissing: true, logger: Logger(label: "local-grib-test"))
        let selected = try #require(selection.first).matches
        // Match selected records to positions in the complete local file. Keep only
        // the first occurrence, just as the production index decoder does.
        let lines = index.split(separator: "\n")
        var seen = Set<String>()
        let records = lines.map { line -> NcepRrfsDownloadVariable? in
            guard let input = selected.first(where: { $0.matches(indexLine: line) }),
                  let name = input.gribIndexName, seen.insert(name).inserted else { return nil }
            return input
        }
        var offset = 0
        var decoded = 0
        for try await message in try GribFileAsyncSequence(fileName: path, multiSupport: true) {
            try #require(offset < records.count)
            let record = records[offset]
            offset += 1
            guard let record else { continue }
            let date = try #require(message.get(attribute: "validityDate"))
            let time = try #require(message.getLong(attribute: "validityTime"))
            let timestamp = try Timestamp.from(yyyymmdd: "\(date)\(time.zeroPadded(len: 4))")
            let runDate = try #require(message.get(attribute: "dataDate"))
            let runTime = try #require(message.getLong(attribute: "dataTime"))
            let run = try Timestamp.from(yyyymmdd: "\(runDate)\(runTime.zeroPadded(len: 4))")
            #expect(timestamp == run.add(record.minute * 60))
            var array = try message.to2D(nx: 1799, ny: 1059, shift180LongitudeAndFlipLatitudeIfRequired: false).array
            record.variable.convertUnits(data: &array.data)
            #expect(array.data.contains { $0.isFinite })
            if record.variable.rawValue == "temperature_2m" { #expect(array.data.allSatisfy { $0.isNaN || (-100...70).contains($0) }) }
            if record.variable.rawValue == "convective_inhibition" { #expect(array.data.allSatisfy { $0.isNaN || $0 >= 0 }) }
            decoded += 1
        }
        #expect(offset == lines.count)
        #expect(decoded == selected.count)
        #expect(decoded > 10)
    }

}

private struct ProbabilityTestDomain: GenericDomain {
    var grid: any Gridable { RegularGrid(nx: 4, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1) }
    var domainRegistry: DomainRegistry { .ncep_rrfs_conus_ensemble }
    var domainRegistryStatic: DomainRegistry? { nil }
    var dtSeconds: Int { 3600 }
    var updateIntervalSeconds: Int { 21600 }
    var hasYearlyFiles: Bool { false }
    var masterTimeRange: Range<Timestamp>? { nil }
    var omFileLength: Int { 157 }
    var countEnsembleMember: Int { 5 }
}
