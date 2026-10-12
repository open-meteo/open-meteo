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

    @Test(arguments: [IconNativeDomains.iconNative, .iconEuNative, .iconD2Native])
    func modelLevelDomainsShareStaticResourcesOnly(parent: IconNativeDomains) throws {
        let modelLevel = try #require(parent.modelLevelDomain)
        #expect(modelLevel.modelLevelParent == parent)
        #expect(modelLevel.domainRegistry != parent.domainRegistry)
        #expect(modelLevel.domainRegistryStatic == parent.domainRegistry)
        #expect(modelLevel.nativeGridFile.getFilePath() == parent.nativeGridFile.getFilePath())
        #expect(modelLevel.domainRegistry.nativeDefinition == modelLevel)
        let metadata = try #require(modelLevel.domainRegistry.timeSeriesMetadata)
        #expect(metadata.dtSeconds == parent.dtSeconds)
        #expect(metadata.omFileLength == parent.omFileLength)
        for variable in IconSurfaceVariable.allCases {
            #expect((IconModelLevelVariable(rawValue: variable.rawValue) != nil)
                    == (variable.getVarAndLevel(domain: parent.sourceDomain)?.cat == "model-level"))
        }
        #expect(IconModelLevelVariable(rawValue: "temperature_850hPa") == nil)
        #expect(IconModelLevelVariable(rawValue: "temperature_2m") == nil)
    }

    @Test func d2DownloadOutputs() async throws {
        let deterministic = try await IconDownloadDomains(.iconD2)
        #expect(deterministic.fifteenMinute?.domainRegistry == .dwd_icon_d2_15min)
        #expect(deterministic.ensembleMean == nil)

        let ensemble = try await IconDownloadDomains(.iconD2Eps)
        #expect(ensemble.ensembleMean?.domainRegistry == IconDomains.iconD2EpsEnsembleMean.domainRegistry)
        #expect(ensemble.fifteenMinute == nil)
    }
}
