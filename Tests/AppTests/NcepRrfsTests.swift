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

    @Test func allDownloadedSurfaceVariablesAreExposed() throws {
        for domain in NcepRrfsDomain.allCases {
            for hour in [0, 1] where hour > 0 || domain != .ncep_rrfs_conus_15min {
                for field in domain.downloadVariables(forecastHour: hour, pressureFile: false) {
                    let name = field.variable.rawValue
                    #expect(ForecastSurfaceVariable(rawValue: name) != nil, "Missing API variable: \(domain) / \(name)")
                    #expect(ForecastVariable(rawValue: name) != nil, "Cannot parse forecast variable: \(name)")
                }
            }
        }
        #expect(ForecastSurfaceVariable(rawValue: "precipitation_probability") != nil)
    }

    @Test func verticalVelocityRemainsInMetresPerSecond() throws {
        let variable = try #require(NcepRrfsConusPressureVariable(rawValue: "vertical_velocity_500hPa"))
        #expect(variable.gribInput.parameter == "DZDT")
        #expect(variable.multiplyAdd == nil)
        let units = ApiUnits(temperature_unit: nil, windspeed_unit: nil, wind_speed_unit: .kmh, precipitation_unit: nil, length_unit: nil)
        let result = DataAndUnit([-2, 0, 3], variable.unit).convertAndRound(params: units)
        #expect(result.data == [-2, 0, 3])
        #expect(result.unit == .metrePerSecondNotUnitConverted)
        #expect(result.unit.abbreviation == "m/s")
    }

    @Test func aerosolOpticalDepthMetadataAndSelection() throws {
        #expect(ForecastSurfaceVariable(rawValue: "aerosol_optical_depth") != nil)
        for domain in NcepRrfsDomain.allCases {
            for hour in [0, 1] where hour > 0 || domain != .ncep_rrfs_conus_15min {
                let fields = domain.downloadVariables(forecastHour: hour, pressureFile: false)
                    .filter { $0.variable.rawValue == "aerosol_optical_depth" }
                #expect(fields.count == (domain == .ncep_rrfs_conus_15min ? 0 : 1))
                for field in fields {
                    #expect(field.variable.unit == .dimensionless)
                    #expect(field.variable.scalefactor == 100)
                    #expect(!field.variable.isElevationCorrectable)
                    #expect(field.interval.type == "instant")
                    #expect(!field.requiresSolarBackwardsConversion)
                    #expect(field.gribIndexName == ":AOTK:entire atmosphere (considered as a single layer):\(hour == 0 ? "anl" : "1 hour fcst"):")
                    var data: [Float] = [0, 0.12, 1.5, .nan]
                    field.variable.convertUnits(data: &data)
                    #expect(Array(data.prefix(3)) == [0, 0.12, 1.5])
                    #expect(data[3].isNaN)
                }
            }
        }
    }

    @Test func particulateMatterUsesLastHourTotalAerosol() async throws {
        let index = """
        1:0:d=2026092000:MASSDEN:8 m above ground:3 hour fcst:aerosol=Particulate organic matter dry:aerosol_size <2.5e-06:
        2:100:d=2026092000:MASSDEN:8 m above ground:0-3 hour ave fcst:aerosol=Total aerosol:aerosol_size <2.5e-06
        3:200:d=2026092000:MASSDEN:8 m above ground:2-3 hour ave fcst:aerosol=Total aerosol:aerosol_size <1e-05
        4:300:d=2026092000:MASSDEN:8 m above ground:2-3 hour ave fcst:aerosol=Total aerosol:aerosol_size <2.5e-06
        """
        for (variable, range) in [(NcepRrfsSurfaceVariable.pm2_5, "300-"), (.pm10, "200-299")] {
            #expect(variable.unit == .microgramsPerCubicMetre)
            #expect(variable.scalefactor == 10)
            #expect(variable.gribIndexName(minute: 0) == nil)
            #expect(ForecastSurfaceVariable(rawValue: variable.rawValue) != nil)
            let field = NcepRrfsDownloadVariable(variable: variable, minute: 180)
            #expect(field.interval.start == 120)
            #expect(field.interval.type == "avg")
            #expect(!field.requiresSolarBackwardsConversion)
            let decoded = try Curl.decodeGribIndices(indices: [index], variables: [field], errorOnMissing: true, logger: Logger(label: "rrfs-pm-test"))
            #expect(decoded.count == 1)
            #expect(decoded[0].range == range)
            let deaverager = GribDeaverager()
            for hour in 1...3 {
                var values: [Float] = [Float(hour) * 10e-9, .nan]
                variable.convertUnits(data: &values)
                var array = Array2D(data: values, nx: 2, ny: 1)
                let interval = variable.gribStep.interval(minute: hour * 60)
                let keep = await deaverager.deaccumulateIfRequired(variable: variable.rawValue, member: 0, stepType: interval.type, stepRange: "\(interval.start)-\(hour * 60)", array2d: &array)
                #expect(keep)
                #expect(abs(array.data[0] - Float(hour) * 10) < 0.00001)
                #expect(array.data[1].isNaN)
            }
            for domain in NcepRrfsDomain.allCases {
                let analysis = domain.downloadVariables(forecastHour: 0, pressureFile: false)
                #expect(!analysis.contains { $0.variable.rawValue == variable.rawValue })
                let forecast = domain.downloadVariables(forecastHour: 1, pressureFile: false)
                #expect(forecast.contains { $0.variable.rawValue == variable.rawValue } == (domain == .ncep_rrfs_conus || domain == .ncep_rrfs_north_america))
            }
        }
    }

    private struct AerosolReader<Variable: GenericVariable>: GenericReaderProtocol {
        typealias MixingVar = Variable
        let modelLat: Float = 45
        let modelLon: Float = -100
        let modelElevation: ElevationOrSea = .elevation(100)
        let targetElevation: Float = 100
        let modelDtSeconds = 3600
        func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
        func prefetchData(variable: Variable, time: TimerangeDtAndSettings) async throws {}
        func get(variable: Variable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
            DataAndUnit([12.5], variable.unit)
        }
    }

    @Test func legacyMassDensityAliasPreservesHrrr() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "rrfs-aerosol-alias"), httpClient: nil)
        let time = TimerangeDtAndSettings(time: TimerangeDt(start: Timestamp(2026, 9, 20), nTime: 1, dtSeconds: 3600), ensembleMember: 0, ensembleMemberLevel: 0, previousDay: 0, run: nil)
        let legacy = try #require(ForecastVariable(rawValue: "mass_density_8m"))
        let organic = try #require(ForecastVariable(rawValue: "pm2_5_total_organic_matter"))
        #expect(NcepRrfsSurfaceVariable(rawValue: "mass_density_8m") == nil)
        #expect(NcepRrfsSurfaceVariable.pm2_5_total_organic_matter.omFileName.file == "pm2_5_total_organic_matter")
        for domain in [DomainRegistry.ncep_rrfs_conus, .ncep_rrfs_north_america] {
            let rrfs = VariableHourlyDeriver(reader: AerosolReader<NcepRrfsSurfaceVariable>(), options: options, domainRegistry: domain)
            guard case .direct(let input) = rrfs.getDeriverMap(variable: legacy) else {
                Issue.record("Expected direct RRFS organic-aerosol alias")
                continue
            }
            #expect(input == .pm2_5_total_organic_matter)
            let oldResult = try await rrfs.get(variable: legacy, time: time)
            let newResult = try await rrfs.get(variable: organic, time: time)
            #expect(oldResult?.data == [12.5])
            #expect(oldResult?.data == newResult?.data)
            #expect(oldResult?.unit == .microgramsPerCubicMetre)
        }
        let hrrr = VariableHourlyDeriver(reader: AerosolReader<HrrrSurfaceVariable>(), options: options, domainRegistry: .ncep_hrrr_conus)
        guard case .direct(let input) = hrrr.getDeriverMap(variable: legacy) else {
            Issue.record("Expected native HRRR mass density")
            return
        }
        #expect(input == .mass_density_8m)
        #expect(input.omFileName.file == "mass_density_8m")
        #expect(hrrr.getDeriverMap(variable: organic) == nil)
    }

    @Test func massDensitySelectsOrganicAerosol() throws {
        let variable = NcepRrfsSurfaceVariable.pm2_5_total_organic_matter
        #expect(variable.unit == .microgramsPerCubicMetre)
        #expect(variable.scalefactor == HrrrSurfaceVariable.mass_density_8m.scalefactor)
        #expect(!variable.skipHour0)
        #expect(ForecastSurfaceVariable(rawValue: variable.rawValue) != nil)
        var values: [Float] = [0, 1e-9, 25e-9, .nan]
        variable.convertUnits(data: &values)
        #expect(values[0] == 0)
        #expect(abs(values[1] - 1) < 0.00001)
        #expect(abs(values[2] - 25) < 0.00001)
        #expect(values[3].isNaN)
        for (hour, step) in [(0, "anl"), (1, "1 hour fcst")] {
            let field = NcepRrfsDownloadVariable(variable: variable, minute: hour * 60)
            let index = """
            1:0:d=2026092000:MASSDEN:8 m above ground:\(step):aerosol=Dust dry:aerosol_size <2.5e-06:
            2:100:d=2026092000:MASSDEN:8 m above ground:0-1 hour ave fcst:aerosol=Total aerosol:aerosol_size <2.5e-06
            3:200:d=2026092000:MASSDEN:8 m above ground:\(step):aerosol=Particulate organic matter dry:aerosol_size <2.5e-06:
            4:300:d=2026092000:MASSDEN:8 m above ground:\(step):aerosol=Dust dry:aerosol_size >=2.5e-06,<1e-05:
            """
            let decoded = try Curl.decodeGribIndices(indices: [index], variables: [field], errorOnMissing: true, logger: Logger(label: "rrfs-aerosol-test"))
            #expect(decoded.count == 1)
            #expect(decoded[0].range == "200-299")
            #expect(field.interval.type == "instant")
            let wrapped = NcepRrfsVariable.surface(variable)
            #expect(wrapped.gribIndexName(minute: hour * 60) == field.gribIndexName)
        }
        for domain in [NcepRrfsDomain.ncep_rrfs_conus_15min, .ncep_rrfs_conus_ensemble] {
            #expect(!domain.downloadVariables(forecastHour: 1, pressureFile: false).contains { $0.variable.rawValue == variable.rawValue })
        }
    }

    @Test func radarReflectivity() throws {
        #expect(ForecastSurfaceVariable(rawValue: "radar_reflectivity") != nil)
        for domain in NcepRrfsDomain.allCases {
            let fields = domain.downloadVariables(forecastHour: 1, pressureFile: false)
                .filter { $0.variable.rawValue == "radar_reflectivity" }
            #expect(fields.count == (domain == .ncep_rrfs_conus_15min ? 4 : 1))
            for field in fields {
                #expect(field.variable.unit == .undefined) // TODO: Expect dBZ once supported by the SDK.
                #expect(field.variable.scalefactor == 10)
                #expect(!field.variable.isElevationCorrectable)
                #expect(field.interval.type == "instant")
                #expect(!field.requiresSolarBackwardsConversion)
                var values: [Float] = [-20, 0, 12.5, 65, .nan]
                field.variable.convertUnits(data: &values)
                #expect(Array(values.prefix(4)) == [-20, 0, 12.5, 65])
                #expect(values[4].isNaN)
                #expect(field.gribIndexName == ":REFC:entire atmosphere (considered as a single layer):\(field.minute == 60 ? "1 hour" : "\(field.minute) min") fcst:")
            }
        }
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
        let grid = NcepRrfsDomain.ncep_rrfs_conus.conusGrid
        #expect(grid.nx == 1799 && grid.ny == 1059)
        #expect(grid.dx == 3000 && grid.dy == 3000)
        let origin = grid.getCoordinates(gridpoint: 0)
        #expect(abs(origin.latitude - 21.1381) < 0.001)
        #expect(abs(origin.longitude + 122.72) < 0.001)
        let north = grid.getTrueNorthDirection()
        #expect(north.allSatisfy { $0.isFinite })
        #expect(abs(north[0]) > 10)
    }

    @Test func northAmericaGridAndMapping() throws {
        let domain = NcepRrfsDomain.ncep_rrfs_north_america
        let grid = domain.northAmericaGrid
        #expect(grid.nx == 1127 && grid.ny == 683 && grid.count == 769741)
        #expect(domain.domainRegistryStatic == .ncep_rrfs_north_america)
        #expect(domain.forecastHours == 0...84)
        #expect(domain.dtSeconds == 3600 && domain.updateIntervalSeconds == 21600)
        #expect(domain.countEnsembleMember == 1)
        // Geographic positions independently decoded by ecCodes from the supplied GRIB.
        for (point, latitude, longitude) in [(0, Float(-1.557), Float(-157.379)),
                                            (1126, -1.526, -68.651),
                                            (384870, 55.000, -113.047),
                                            (769740, 41.500, -1.908)] {
            let coordinates = grid.getCoordinates(gridpoint: point)
            #expect(abs(coordinates.latitude - latitude) < 0.002)
            #expect(abs(coordinates.longitude - longitude) < 0.002)
            #expect(grid.findPoint(lat: coordinates.latitude, lon: coordinates.longitude) == point)
        }
        let north = grid.getTrueNorthDirection()
        #expect(north.allSatisfy { $0.isFinite })
        // Compare spherical rotation with an independent local projection derivative.
        for point in [0, 1126, 384870, 769740] {
            let coordinates = grid.getCoordinates(gridpoint: point)
            let origin = grid.projection.forward(latitude: coordinates.latitude, longitude: coordinates.longitude)
            let geographicNorth = grid.projection.forward(latitude: coordinates.latitude + 0.01, longitude: coordinates.longitude)
            let angle = atan2((geographicNorth.x - origin.x) * cos(origin.y.degreesToRadians), geographicNorth.y - origin.y).radiansToDegrees
            #expect(abs(north[point] - angle) < 0.2)
        }
        let urls = domain.gribUrls(run: Timestamp(2026, 9, 24), forecastHour: 84, member: 0, server: "https://example.com")
        #expect(urls == ["2dfld", "prslev"].map { "https://example.com/rrfs.20260924/00/rrfs.t00z.\($0).13km.f084.na.grib2" })
        let model = try #require(MultiDomains(rawValue: domain.rawValue))
        guard case .single(let source, let variables) = model.getDomainAndVariable() else {
            Issue.record("Expected North America RRFS reader")
            return
        }
        #expect(source.domainRegistry == .ncep_rrfs_north_america)
        #expect(ObjectIdentifier(variables) == ObjectIdentifier(NcepRrfsVariable.self))
        #expect(model.genericDomain?.domainRegistry == .ncep_rrfs_north_america)
        #expect(model.flatBufferModel == .undefined)
    }

    @Test func hourlyInventorySelectionAndCatalogCoverage() throws {
        let fields = try records("rrfs.t00z.2dfld.3km.f001.conus.grib2.idx", domain: .ncep_rrfs_conus)
        #expect(fields.filter { $0.variable.rawValue == "shortwave_radiation" }.map { $0.interval.type } == ["avg"])
        #expect(fields.filter { $0.variable.rawValue == "cloud_cover" }.map { $0.interval.type } == ["instant"])
        let names = Set(fields.map { $0.variable.rawValue })
        for required in ["cape", "convective_inhibition", "boundary_layer_height", "wind_speed_320m", "soil_temperature_0cm", "soil_moisture_300cm"] {
            #expect(names.contains(required))
        }
        for height in [305, 457, 610, 914, 1524, 1829, 2134, 2743, 3658, 4572] {
            #expect(NcepRrfsSurfaceVariable(rawValue: "wind_speed_\(height)m") == nil)
            #expect(NcepRrfsSurfaceVariable(rawValue: "wind_direction_\(height)m") == nil)
            #expect(NcepRrfsSurfaceVariable(rawValue: "temperature_\(height)m") == nil)
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
        #expect(files.count == 12)
        for file in files {
            let name = file.lastPathComponent
            let domain: NcepRrfsDomain = name.contains("13km") ? .ncep_rrfs_north_america : name.contains("m001") ? .ncep_rrfs_conus_ensemble : name.contains("subh") ? .ncep_rrfs_conus_15min : .ncep_rrfs_conus
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

    @Test func cloudHeightsAndWaterAmounts() throws {
        var heights: [Float] = [1500, 300, 50, .nan, -99999, 1000]
        NcepRrfsSurfaceVariable.cloud_base.convertCloudHeightToAboveGround(
            data: &heights, elevation: [500, -999, 100, 0, 0, .nan])
        #expect(Array(heights.prefix(3)) == [1000, 300, 0])
        #expect(heights.suffix(3).allSatisfy { $0.isNaN })
        var snowpack: [Float] = [0, 25.5, 100]
        NcepRrfsSurfaceVariable.snow_depth_water_equivalent.convertUnits(data: &snowpack)
        #expect(snowpack == [0, 25.5, 100])
        #expect(NcepRrfsSurfaceVariable.snow_depth_water_equivalent.gribStep == .instant)
        #expect(!NcepRrfsSurfaceVariable.snow_depth_water_equivalent.skipHour0)
        #expect(NcepRrfsSurfaceVariable.snow_depth_water_equivalent.unit == .millimetre)
        #expect(ForecastSurfaceVariable(rawValue: "cloud_top") != nil)
        #expect(ForecastSurfaceVariable(rawValue: "cloud_ceiling") != nil)
        #expect(ForecastSurfaceVariable(rawValue: "freezing_rain") != nil)
        for domain in NcepRrfsDomain.allCases {
            let inputs = domain.downloadVariables(forecastHour: 3, pressureFile: false)
            let freezingRain = inputs.filter { $0.variable.rawValue == "freezing_rain" }
            #expect(freezingRain.count == (domain == .ncep_rrfs_conus_15min ? 4 : 1))
            #expect(freezingRain.allSatisfy { $0.interval.start == 0 && $0.interval.type == "accum" && $0.variable.skipHour0 })
            #expect(inputs.filter { $0.variable.isCloudHeight }.count == (domain == .ncep_rrfs_conus_ensemble ? 0 : domain == .ncep_rrfs_conus_15min ? 12 : 3))
        }
        for variable in [NcepRrfsSurfaceVariable.cloud_base, .cloud_ceiling, .cloud_top] {
            let input = NcepRrfsDownloadVariable(variable: variable, minute: 60)
            let index = "1:0:d=2026092400:HGT:cloud base:1 hour fcst:\n2:100:d=2026092400:HGT:cloud ceiling:1 hour fcst:\n3:200:d=2026092400:HGT:cloud top:1 hour fcst:"
            let decoded = try Curl.decodeGribIndices(indices: [index], variables: [input], errorOnMissing: true, logger: Logger(label: "cloud-height-test"))
            #expect(decoded[0].matches.count == 1)
            switch variable {
            case .cloud_base: #expect(decoded[0].range == "0-99")
            case .cloud_ceiling: #expect(decoded[0].range == "100-199")
            case .cloud_top: #expect(decoded[0].range == "200-")
            default: Issue.record("Unexpected cloud variable")
            }
        }
        let freezingRain = NcepRrfsDownloadVariable(variable: NcepRrfsSurfaceVariable.freezing_rain, minute: 180)
        let decoded = try Curl.decodeGribIndices(indices: ["1:0:d=2026092400:FRZR:surface:0-3 hour acc fcst:\n2:100:d=2026092400:FRZR:surface:2-3 hour acc fcst:"], variables: [freezingRain], errorOnMissing: true, logger: Logger(label: "freezing-rain-test"))
        #expect(decoded[0].matches.count == 1)
        #expect(decoded[0].range == "0-99")
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
        #expect(NcepRrfsSurfaceVariable.wind_direction_320m.unit == .degreeDirection)
    }

    @Test func chronologicalDeaccumulationAcrossHourAndMemberBoundaries() async throws {
        let records = try (1...2).flatMap { hour in
            try self.records("rrfs.t00z.2dfld.3km.subh.f00\(hour).conus.grib2.idx", domain: .ncep_rrfs_conus_15min)
        }
        let deaverager = GribDeaverager()
        for variable in ["precipitation", "snowfall_water_equivalent", "freezing_rain"] {
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
            var array = try message.to2D(nx: domain.grid.nx, ny: domain.grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
            record.variable.convertUnits(data: &array.data)
            #expect(array.data.contains { $0.isFinite })
            if domain == .ncep_rrfs_north_america && record.variable.rawValue == "temperature_2m" {
                #expect(array.data.count == 769741)
                #expect(array.data.first?.isNaN == true)
                #expect(array.data[384870].isFinite)
            }
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
