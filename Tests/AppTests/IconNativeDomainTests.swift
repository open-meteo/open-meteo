import Foundation
@testable import App
import Testing
import Logging

@Suite struct IconNativeDomainTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_DOMAIN_TESTS"] == "1"))
    func concurrentNativeLoadsShareResources() async throws {
        let cache = IconNativeDomainCache()
        let context = DomainInitContext(logger: Logger(label: "NativeDomainCacheTests"), httpClient: nil)
        let domains = try await withThrowingTaskGroup(of: IconNativeDomain.self) { group in
            for index in 0..<20 {
                group.addTask {
                    try await cache.load(index.isMultiple(of: 2) ? .iconD2Native : .iconD2Native15min, context: context)
                }
            }
            var domains = [IconNativeDomain]()
            for try await domain in group { domains.append(domain) }
            return domains
        }
        let first = try #require(domains.first)
        let elevationCache = try #require(first.nativeGrid.elevationPayload?.elevationCache)
        for domain in domains {
            #expect(domain.nativeGrid.storage === first.nativeGrid.storage)
            #expect(domain.nativeGrid.elevationPayload?.elevationCache === elevationCache)
            #expect(domain.dtSeconds == (domain.definition == .iconD2Native ? 3600 : 900))
        }
        let reused = try await cache.load(.iconD2Native, context: context)
        #expect(reused.nativeGrid.storage === first.nativeGrid.storage)
        #expect(reused.nativeGrid.elevationPayload?.elevationCache === elevationCache)
        #expect(elevationCache.cachedValues == nil)
    }

    @Test func nativeMetadataDoesNotRequireStaticFiles() throws {
        let metadata = try #require(DomainRegistry.dwd_icon_d2_native_15min.timeSeriesMetadata)
        #expect(metadata.dtSeconds == 900)
        #expect(metadata.omFileLength == IconDomains.iconD2_15min.omFileLength)
        #expect(metadata.updateIntervalSeconds == IconDomains.iconD2_15min.updateIntervalSeconds)
    }

    @Test func d2DownloadOutputs() async throws {
        let context = DomainInitContext(logger: Logger(label: "IconDownloadDomains"), httpClient: nil)
        let deterministic = try await IconDownloadDomains(.iconD2, context: context)
        #expect(deterministic.fifteenMinute?.domainRegistry == .dwd_icon_d2_15min)
        #expect(deterministic.ensembleMean == nil)

        let ensemble = try await IconDownloadDomains(.iconD2Eps, context: context)
        #expect(ensemble.ensembleMean?.domainRegistry == IconDomains.iconD2EpsEnsembleMean.domainRegistry)
        #expect(ensemble.fifteenMinute == nil)
    }

    @Test func globalRemappingGathersNativeCellsAndPreservesMissingDestinations() {
        let remapper = CdoIconGlobal(mapping: [2, -1, 0, 2])
        let remapped = remapper.remap([10, 20, 30])

        #expect(remapped[0] == 30)
        #expect(remapped[1].isNaN)
        #expect(remapped[2] == 10)
        #expect(remapped[3] == 30)
    }

    @Test func d2DomainsShareGridCache() {
        let global = IconNativeDomains.iconNative.nativeGridFile
        let hourly = IconNativeDomains.iconD2Native.nativeGridFile
        let quarterHourly = IconNativeDomains.iconD2Native15min.nativeGridFile
        #expect(hourly.cache === quarterHourly.cache)
        #expect(global.cache !== hourly.cache)
        #expect(hourly.registry == .dwd_icon_d2_native)
    }
}
