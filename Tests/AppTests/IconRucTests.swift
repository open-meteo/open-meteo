import Foundation
import Logging
import Testing
@testable import App

@Suite struct IconRucTests {
    @Test func sourceAndStorageMetadata() throws {
        let parent = IconNativeDomains.iconD2RucNative
        let quarter = IconNativeDomains.iconD2RucNative15min
        let levels = try #require(parent.modelLevelDomain)
        #expect(parent.sourceDomain == .iconD2Ruc)
        #expect(parent.dtSeconds == 3600)
        #expect(quarter.dtSeconds == 900)
        #expect(parent.updateIntervalSeconds == 3600)
        #expect(quarter.omFileLength == 397)
        #expect(levels.modelLevelParent == parent)
        #expect(levels.domainRegistryStatic == parent.domainRegistry)
        #expect(quarter.domainRegistryStatic == parent.domainRegistry)
        #expect(parent.nativeGridFile.identity == .d2)
        #expect(parent.nativeGridFile.getFilePath() == IconNativeDomains.iconD2Native.nativeGridFile.getFilePath())
        #expect(parent.domainRegistryStatic != IconNativeDomains.iconD2Native.domainRegistryStatic)
        for definition in [parent, quarter, levels] {
            let metadata = try #require(definition.domainRegistry.timeSeriesMetadata)
            #expect(metadata.dtSeconds == definition.dtSeconds)
            #expect(metadata.updateIntervalSeconds == 3600)
            #expect(definition.domainRegistry.nativeDefinition == definition)
        }
    }

    @Test func forecastEndpointsAndUrls() {
        let domain = IconDomains.iconD2Ruc
        for hour in 0..<24 {
            #expect(domain.getDownloadForecastSteps(run: hour) == Array(0...27))
        }
        let steps = (0...27).flatMap { domain.downloadLeadSeconds(hour: $0, quarterHourly: true) }
        #expect(steps == Array(stride(from: 0, through: 27 * 3600, by: 900)))
        #expect(domain.downloadLeadSeconds(hour: 27, quarterHourly: true) == [27 * 3600])
        #expect(domain.downloadLeadSeconds(hour: 28, quarterHourly: true).isEmpty)
        #expect(domain.downloadLeadSeconds(hour: 0, quarterHourly: false) == [0])
        let run = Timestamp(2026, 10, 7, 23)
        let url = domain.getGribUrl(field: ("TOT_PREC", "single-level", nil), run: run, leadSeconds: 4500)
        #expect(url.hasSuffix("icon-d2-ruc/p/TOT_PREC/r/2026-10-07T23:00/s/PT001H15M.grib2"))
        #expect(domain.getGribUrl(field: ("T", "pressure-level", 850), run: run, leadSeconds: 3600).contains("/lvt1/100/lv1/85000/"))
        #expect(domain.getGribUrl(field: ("U", "model-level", 63), run: run, leadSeconds: 3600).contains("/lvt1/150/lv1/63/"))
    }

    @Test func capabilitiesPreventUnavailableDownloads() {
        #expect(IconSurfaceVariable.visibility.getVarAndLevel(domain: .iconD2Ruc)?.variable == "VIS")
        #expect(IconSurfaceVariable.visibility.getVarAndLevel(domain: .iconD2) == nil)
        #expect(IconSurfaceVariable.precipitation.hasQuarterHourlyData(domain: .iconD2Ruc))
        #expect(IconSurfaceVariable.convective_inhibition.hasQuarterHourlyData(domain: .iconD2Ruc))
        #expect(!IconSurfaceVariable.temperature_2m.hasQuarterHourlyData(domain: .iconD2Ruc))
        #expect(!IconSurfaceVariable.wind_gusts_10m.hasQuarterHourlyData(domain: .iconD2Ruc))
        for variable in [IconSurfaceVariable.showers, .soil_temperature_6cm, .sensible_heat_flux, .convective_cloud_top, .snowfall_convective_water_equivalent] {
            #expect(variable.getVarAndLevel(domain: .iconD2Ruc) == nil)
        }
        for level in IconDomains.iconD2Ruc.levels {
            let humidity = IconPressureVariable(variable: .relative_humidity, level: level)
            #expect(humidity.getVarAndLevel(domain: .iconD2Ruc)?.variable == ([500, 700].contains(level) ? "relhum" : "QV"))
            #expect(!humidity.requiresSpecificHumidityConversion(domain: .iconD2))
        }
        #expect(IconSurfaceVariable.temperature_80m.getVarAndLevel(domain: .iconD2Ruc)?.level == 63)
    }

    @Test func independentAccumulationsConservePrecipitation() async {
        let hourly = GribDeaverager()
        let quarter = GribDeaverager()
        let variable = IconSurfaceVariable.precipitation
        var total: Float = 0
        for (i, cumulative) in [Float(0), 1, 3, 6, 10].enumerated() {
            var data = Array2D(data: [cumulative], nx: 1, ny: 1)
            let write = await quarter.deaccumulateIfRequired(variable: variable, member: 0, stepType: "accum", startStep: 0, currentStep: i * 900, array2d: &data)
            #expect(write == (i > 0))
            if write { total += data.data[0] }
        }
        var data = Array2D(data: [Float(10)], nx: 1, ny: 1)
        #expect(await hourly.deaccumulateIfRequired(variable: variable, member: 0, stepType: "accum", startStep: 0, currentStep: 3600, array2d: &data))
        #expect(data.data[0] == total)
        #expect(total == 10)
        // A new run gets fresh state, never the preceding run's final accumulation.
        let nextRun = GribDeaverager()
        data.data = [2]
        #expect(await nextRun.deaccumulateIfRequired(variable: variable, member: 0, stepType: "accum", startStep: 0, currentStep: 900, array2d: &data))
        #expect(data.data == [2])
    }

    @Test func radiationUsesSecondsForAveraging() async throws {
        let state = GribDeaverager()
        var data = Array2D(data: [Float(100)], nx: 1, ny: 1)
        let first = try IconStepInterval(start: 0, end: 15, unit: 0)
        #expect(await state.deaccumulateIfRequired(variable: IconSurfaceVariable.direct_radiation, member: 0, stepType: "avg", startStep: first.start, currentStep: first.end, array2d: &data))
        data.data = [150]
        let second = try IconStepInterval(start: 0, end: 1800, unit: 13)
        #expect(await state.deaccumulateIfRequired(variable: IconSurfaceVariable.direct_radiation, member: 0, stepType: "avg", startStep: second.start, currentStep: second.end, array2d: &data))
        #expect(data.data == [200])
    }

    @Test func intervalMaximumReaderAggregation() throws {
        let variable = try #require(IconRucVariable(rawValue: "updraft"))
        let run = Timestamp(2026, 10, 7, 12)
        let hour = TimerangeDt(start: run.add(3600), nTime: 1, dtSeconds: 3600)
        let quarters = hour.forAggregationTo(modelDt: 900, interpolation: variable.interpolation)
        #expect(quarters.range.lowerBound == run.add(900))
        #expect([Float(2), 9, 4, 1].aggregate(type: variable.interpolation, timeOld: quarters, timeNew: hour) == [9])
        #expect([Float(2), .nan, 4, 1].aggregate(type: variable.interpolation, timeOld: quarters, timeNew: hour)[0].isNaN)
    }

    @Test func correctionDependenciesAreSpecificToTheRequestedField() {
        #expect(IconSurfaceVariable.freezing_level_height.rucCorrectionDependencies == [.temperature_2m])
        #expect(IconSurfaceVariable.snowfall_height.rucCorrectionDependencies == [.temperature_2m])
        #expect(IconSurfaceVariable.snowfall_water_equivalent.rucCorrectionDependencies == [.temperature_2m, .snowfall_height])
        #expect(IconSurfaceVariable.rain.rucCorrectionDependencies == [.temperature_2m, .snowfall_height, .snowfall_water_equivalent])
        #expect(IconSurfaceVariable.weather_code.rucCorrectionDependencies == [.temperature_2m, .precipitation, .snowfall_height])
        #expect(IconSurfaceVariable.precipitation.rucCorrectionDependencies.isEmpty)
    }

    @Test func derivedVariablesUseInputsFromBothCadences() async throws {
        let options = try GenericReaderOptions(logger: Logger(label: "IconRucTests"), httpClient: nil)
        let hourly = RucRawFixture(values: ["temperature_2m": 20, "relative_humidity_2m": 50, "wind_u_component_10m": 3, "wind_v_component_10m": 4], modelDtSeconds: 3600)
        let quarter = RucRawFixture(values: ["direct_radiation": 700, "diffuse_radiation": 100], modelDtSeconds: 900)
        let complete = RucRawFixture(values: hourly.values.merging(quarter.values) { _, value in value }, modelDtSeconds: 900)
        let mixed = VariableHourlyDeriver(reader: GenericReaderMixerSameVariableType(reader: [hourly, quarter]), options: options, domainRegistry: .dwd_icon_d2_ruc_native)
        let reference = VariableHourlyDeriver(reader: complete, options: options, domainRegistry: .dwd_icon_d2_ruc_native)
        let incomplete = [hourly, quarter].map { VariableHourlyDeriver(reader: $0, options: options, domainRegistry: .dwd_icon_d2_ruc_native) }
        for dt in [900, 3600] {
            let time = TimerangeDt(start: Timestamp(2026, 6, 1, 12), nTime: 1, dtSeconds: dt).toSettings()
            for name in ["apparent_temperature", "et0_fao_evapotranspiration"] {
                let variable = try #require(ForecastVariable(rawValue: name))
                #expect(try await mixed.prefetchData(variable: variable, time: time))
                let actual = try #require(await mixed.get(variable: variable, time: time))
                let expected = try #require(await reference.get(variable: variable, time: time))
                #expect(actual.data.allSatisfy { $0.isFinite })
                #expect(actual.data == expected.data)
                for reader in incomplete {
                    let data = try await reader.get(variable: variable, time: time)
                    // Some derivations substitute missing inputs; neither partial reader
                    // may replace the result calculated from the complete RUC fields.
                    #expect(data?.data != expected.data)
                }
            }
        }
    }

    /// Opt-in check against an ingested mature run; never downloads weather data in the normal suite.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_RUC_LIVE_RUN"] != nil))
    func liveNativeValuesAndQuarterHourConservation() async throws {
        let runString = try #require(ProcessInfo.processInfo.environment["ICON_RUC_LIVE_RUN"])
        let run = try Timestamp.fromRunHourOrYYYYMMDD(runString)
        let options = try GenericReaderOptions(logger: Logger(label: "IconRucLiveTest"), httpClient: nil)
        let domain = try await IconNativeDomains.iconD2RucNative.load()
        let quarter = try await IconNativeDomains.iconD2RucNative15min.load()
        let downloader = IconGribDownloader(domain: .iconD2Ruc, curl: Curl(logger: options.logger, client: .shared, deadLineHours: 0.02), remapper: nil)
        let temperature = try await downloader.downloadAndRemap(field: ("T_2M", "single-level", nil), run: run, leadSeconds: 3600)
        let precip = try await downloader.downloadAndRemap(field: ("TOT_PREC", "single-level", nil), run: run, leadSeconds: 3600)
        let q850 = try await downloader.downloadAndRemap(field: ("QV", "pressure-level", 850), run: run, leadSeconds: 3600)
        let t850 = try await downloader.downloadAndRemap(field: ("T", "pressure-level", 850), run: run, leadSeconds: 3600)
        var positions = [0, domain.nativeGrid.nx - 1]
        let locations: [(Float, Float)] = [(52.52, 13.4), (54.17, 7.9), (47.4, 10.9)]
        for (lat, lon) in locations {
            positions.append(try #require(domain.nativeGrid.findPoint(lat: lat, lon: lon)))
        }
        let hour = TimerangeDt(start: run.add(3600), nTime: 1, dtSeconds: 3600).toSettings()
        let quarters = TimerangeDt(start: run.add(900), nTime: 4, dtSeconds: 900).toSettings()
        for position in positions {
            let reader = try await GenericReader<IconNativeDomain, IconVariable>(domain: domain, position: position, options: options)
            let subhourly = try await GenericReader<IconNativeDomain, IconVariable>(domain: quarter, position: position, options: options)
            let maxima = try await GenericReader<IconNativeDomain, IconRucVariable>(domain: quarter, position: position, options: options)
            let actualTemperature = try await reader.get(variable: .surface(.temperature_2m), time: hour).data[0]
            #expect(abs(actualTemperature - (temperature.data.data[position] - 273.15)) <= 0.11)
            let actualPrecip = try await subhourly.get(variable: .surface(.precipitation), time: hour).data[0]
            let quarterPrecip = try await subhourly.get(variable: .surface(.precipitation), time: quarters).data
            #expect(abs(actualPrecip - precip.data.data[position]) <= 0.11)
            #expect(abs(quarterPrecip.reduce(0, +) - actualPrecip) <= 0.25)
            let humidity = try await reader.get(variable: .pressure(.init(variable: .relative_humidity, level: 850)), time: hour).data[0]
            let expectedHumidity = Meteorology.specificToRelativeHumidity(specificHumidity: q850.data.data[position] * 1000, temperature: t850.data.data[position] - 273.15, pressure: 850)
            #expect(abs(humidity - expectedHumidity) <= 1)
            let updraft = try await maxima.get(variable: #require(IconRucVariable(rawValue: "updraft")), time: hour).data[0]
            let quarterUpdraft = try await subhourly.get(variable: .surface(.updraft), time: quarters).data
            #expect(abs(updraft - (quarterUpdraft.max() ?? .nan)) <= 0.03)
            let endpoint = TimerangeDt(start: run.add(27 * 3600), nTime: 1, dtSeconds: 900).toSettings()
            #expect(try await subhourly.get(variable: .surface(.precipitation), time: endpoint).data[0].isFinite)
        }
    }
}

private struct RucRawFixture: GenericReaderProtocol {
    let values: [String: Float]
    let modelDtSeconds: Int
    let modelLat: Float = 52.5
    let modelLon: Float = 13.4
    let modelElevation = ElevationOrSea.elevation(40)
    let targetElevation: Float = 40

    func getStatic(type: ReaderStaticVariable) async throws -> Float? { nil }
    func prefetchData(variable: IconRucVariable, time: TimerangeDtAndSettings) async throws {}
    func get(variable: IconRucVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        DataAndUnit(Array(repeating: values[variable.rawValue] ?? .nan, count: time.time.count), variable.unit)
    }
}
