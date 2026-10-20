import Foundation
@testable import App
import Testing
import Logging

@Suite struct IconNativeDomainTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_DOMAIN_TESTS"] == "1"))
    func concurrentNativeLoadsShareResources() async throws {
        let cache = IconNativeGridLoader()
        let domains = try await withThrowingTaskGroup(of: IconNativeDomain.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let definition: IconNativeDomains = index.isMultiple(of: 2) ? .iconD2Native : .iconD2Native15min
                    return IconNativeDomain(definition: definition, nativeGrid: try await cache.load(grid: definition.asyncGridRegistry))
                }
            }
            var domains = [IconNativeDomain]()
            for try await domain in group { domains.append(domain) }
            return domains
        }
        let first = try #require(domains.first)
        let firstGrid = try #require(first.grid as? IconNativeGrid)
        let elevations = try #require(firstGrid.elevations)
        for domain in domains {
            let grid = try #require(domain.grid as? IconNativeGrid)
            #expect(grid.storage === firstGrid.storage)
            #expect(grid.elevations === elevations)
            #expect(domain.dtSeconds == (domain.definition == .iconD2Native ? 3600 : 900))
        }
        let reused = try await cache.load(grid: .dwd_icon_d2_native)
        #expect(reused.storage === firstGrid.storage)
        #expect(reused.elevations === elevations)
        #expect(elevations.count == firstGrid.nx)
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
        #expect(modelLevel.gridRegistry == parent.gridRegistry)
        #expect(IconNativeGridFile.forGrid(modelLevel.asyncGridRegistry).getFilePath() == IconNativeGridFile.forGrid(parent.asyncGridRegistry).getFilePath())
        #expect((modelLevel.domainRegistry.definition as? IconNativeDomains) == modelLevel)
        let metadata = try #require(modelLevel.domainRegistry.timeSeriesMetadata)
        #expect(metadata.dtSeconds == parent.dtSeconds)
        #expect(metadata.omFileLength == parent.omFileLength)
        for variable in IconSurfaceVariable.allCases {
            #expect((IconModelLevelVariable(rawValue: variable.rawValue) != nil)
                    == (parent.downloadDomain.getVarAndLevel(variable)?.cat == "model-level"))
        }
        #expect(IconModelLevelVariable(rawValue: "temperature_850hPa") == nil)
        #expect(IconModelLevelVariable(rawValue: "temperature_2m") == nil)
    }

    @Test func d2DownloadOutputs() async throws {
        let deterministic = try await IconDownloadOutputs(.iconD2)
        #expect(deterministic.fifteenMinute?.domainRegistry == .dwd_icon_d2_15min)
        #expect(deterministic.ensembleMean == nil)

        let ensemble = try await IconDownloadOutputs(.iconD2Eps)
        #expect(ensemble.ensembleMean?.domainRegistry == IconDomains.iconD2EpsEnsembleMean.domainRegistry)
        #expect(ensemble.fifteenMinute == nil)

        let run = Timestamp(2026, 10, 7, 0)
        #expect(deterministic.downloadDomain.getGribUrl(field: ("T", "pressure-level", 850), run: run, leadSeconds: 3600)
            .hasSuffix("icon-d2/p/T/lvt1/100/lv1/85000/r/2026-10-07T00:00/s/PT001H00M.grib2"))
        #expect(ensemble.downloadDomain.getGribUrl(field: ("T_2M", "single-level", nil), run: run, leadSeconds: 0, member: 2)
            .hasSuffix("icon-d2-eps/p/T_2M/r/2026-10-07T00:00/e/03/s/PT000H00M.grib2"))
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
