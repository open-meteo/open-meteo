import Foundation
@testable import App
import Testing
import Logging

@Suite struct IconNativeDomainTests {
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
