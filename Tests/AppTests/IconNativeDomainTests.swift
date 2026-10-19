import Foundation
@testable import App
import Testing
import Logging

@Suite struct IconNativeDomainTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_DOMAIN_TESTS"] == "1"))
    func concurrentNativeLoadsShareResources() async throws {
        let cache = IconNativeDomainCache()
        let domains = try await withThrowingTaskGroup(of: IconNativeDomain.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await cache.load(index.isMultiple(of: 2) ? .iconD2Native : .iconD2Native15min)
                }
            }
            var domains = [IconNativeDomain]()
            for try await domain in group { domains.append(domain) }
            return domains
        }
        let first = try #require(domains.first)
        let elevations = try #require(first.nativeGrid.elevations)
        for domain in domains {
            #expect(domain.nativeGrid.storage === first.nativeGrid.storage)
            #expect(domain.nativeGrid.elevations === elevations)
            #expect(domain.dtSeconds == (domain.definition == .iconD2Native ? 3600 : 900))
        }
        let reused = try await cache.load(.iconD2Native)
        #expect(reused.nativeGrid.storage === first.nativeGrid.storage)
        #expect(reused.nativeGrid.elevations === elevations)
        #expect(elevations.count == first.nativeGrid.nx)
    }

    @Test func nativeMetadataDoesNotRequireStaticFiles() throws {
        let metadata = try #require(DomainRegistry.dwd_icon_d2_native_15min.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 900)
        #expect(metadata.omFileLength == IconDomains.iconD2_15min.omFileLength)
        #expect(metadata.updateIntervalSeconds == IconDomains.iconD2_15min.updateIntervalSeconds)
    }

    @Test(arguments: [IconNativeDomains.iconNative, .iconEuNative, .iconD2Native, .iconD2RucNative])
    func modelLevelDomainsShareStaticResourcesOnly(parent: IconNativeDomains) throws {
        let modelLevel = try #require(parent.modelLevelDomain)
        #expect(modelLevel.modelLevelParent == parent)
        #expect(modelLevel.domainRegistry != parent.domainRegistry)
        #expect(modelLevel.domainRegistryStatic == parent.domainRegistryStatic)
        #expect(modelLevel.nativeGridFile.getFilePath() == parent.nativeGridFile.getFilePath())
        #expect(modelLevel.domainRegistry.nativeDefinition == modelLevel)
        let metadata = try #require(modelLevel.domainRegistry.timeSeriesMetadata)
        #expect(metadata.dtSeconds == parent.dtSeconds)
        #expect(metadata.omFileLength == parent.omFileLength)
        for variable in IconSurfaceVariable.allCases {
            #expect((IconModelLevelVariable(rawValue: variable.rawValue) != nil)
                    == (variable.getVarAndLevel(model: parent.sourceModel)?.cat == "model-level"))
        }
        #expect(IconModelLevelVariable(rawValue: "temperature_850hPa") == nil)
        #expect(IconModelLevelVariable(rawValue: "temperature_2m") == nil)
    }

    @Test func d2DownloadOutputs() async throws {
        let deterministic = try await DwdDownloadDomains(.iconD2)
        #expect(deterministic.fifteenMinute?.domainRegistry == .dwd_icon_d2_15min)
        #expect(deterministic.ensembleMean == nil)

        let ensemble = try await DwdDownloadDomains(.iconD2Eps)
        #expect(ensemble.ensembleMean?.domainRegistry == IconDomains.iconD2EpsEnsembleMean.domainRegistry)
        #expect(ensemble.fifteenMinute == nil)

        let run = Timestamp(2026, 10, 7, 0)
        #expect(deterministic.source.getGribUrl(field: ("T", "pressure-level", 850), run: run, leadSeconds: 3600)
            .hasSuffix("icon-d2/p/T/lvt1/100/lv1/85000/r/2026-10-07T00:00/s/PT001H00M.grib2"))
        #expect(ensemble.source.getGribUrl(field: ("T_2M", "single-level", nil), run: run, leadSeconds: 0, member: 2)
            .hasSuffix("icon-d2-eps/p/T_2M/r/2026-10-07T00:00/e/03/s/PT000H00M.grib2"))
    }

    @Test func sharedDwdDownloaderPreservesRucFeed() throws {
        let model = IconNativeDomains.iconD2RucNative.sourceModel
        let run = Timestamp(2026, 10, 7, 6)
        #expect(model == .iconD2Ruc)
        #expect(try model.getDownloadForecastSteps(run: 6) == Array(0...27))
        #expect(model.updateIntervalSeconds == 3600)
        #expect(model.deadlineHours == 1)
        #expect(model.lastRun(now: run) == run.add(hours: -1))
        #expect(model.getGribUrl(field: ("QV", "pressure-level", 850), run: run, leadSeconds: 3600)
            .hasSuffix("icon-d2-ruc/p/QV/lvt1/100/lv1/85000/r/2026-10-07T06:00/s/PT001H00M.grib2"))
        let humidity = IconPressureVariable(variable: .relative_humidity, level: 850)
        #expect(humidity.getVarAndLevel(model: model)?.variable == "QV")
        #expect(model.requiresSpecificHumidityConversion(humidity))
        let batch = model.downloadBatch(variable: IconSurfaceVariable.precipitation, hour: 27)
        #expect(batch.output == .quarterHourly)
        #expect(batch.steps == [27 * 3600])
        let selected = try DownloadIconCommand.variables(model: model, group: .all, onlyVariables: "visibility")
        #expect(selected.first?.getVarAndLevel(model: model)?.variable == "VIS")
        let metadata = try #require(DomainRegistry.dwd_icon_d2_ruc_native_15min.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 900)
        #expect(metadata.updateIntervalSeconds == 3600)
        #expect(metadata.omFileLength == (27 + 72) * 4 + 1)
    }

    @Test func downloadAvailability() {
        let run = Timestamp(2026, 10, 7, 6)
        #expect(IconDownloadDomains.iconD2.downloadBatch(variable: IconSurfaceVariable.showers, hour: 1).output == .quarterHourly)
        #expect(IconDownloadDomains.iconD2Ruc.downloadBatch(variable: IconSurfaceVariable.showers, hour: 1).output == .hourly)
        #expect(IconDownloadDomains.icon.downloadBatch(variable: IconSurfaceVariable.precipitation, hour: 1).output == .hourly)
        #expect(IconDownloadDomains.iconD2Eps.downloadBatch(variable: IconSurfaceVariable.precipitation, hour: 1).output == .hourly)

        for feed in [IconDownloadDomains.iconD2, .iconD2Ruc] {
            #expect(!feed.skipHour(IconSurfaceVariable.precipitation, hour: 0, forDownload: true, run: run))
            #expect(feed.skipHour(IconSurfaceVariable.precipitation, hour: 0, forDownload: false, run: run))
        }
        #expect(IconDownloadDomains.iconEuEps.skipHour(IconSurfaceVariable.cape, hour: 3, forDownload: true, run: run))
        #expect(!IconDownloadDomains.iconEuEps.skipHour(IconSurfaceVariable.cape, hour: 6, forDownload: true, run: run))
        #expect(IconDownloadDomains.iconEps.getVarAndLevel(IconSurfaceVariable.relative_humidity_2m)?.variable == "td_2m")
        #expect(IconDownloadDomains.iconEuEps.getVarAndLevel(IconSurfaceVariable.relative_humidity_2m) == nil)
        #expect(IconDownloadDomains.iconD2.getVarAndLevel(IconSurfaceVariable.relative_humidity_2m)?.variable == "relhum_2m")
    }
}
