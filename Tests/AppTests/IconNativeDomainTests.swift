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

    @Test func configuredGridIdentities() throws {
        #expect(IconNativeGridIdentity.global.gridNumber == 26)
        #expect(IconNativeGridIdentity.global.gridUUIDHex == "a27b8de618c411e4820ab5b098c6a5c0")
        #expect(IconNativeGridIdentity.global.cellCount == 2_949_120)
        #expect(IconNativeGridIdentity.global.maximumDistanceMeters == 20_000)
        #expect(IconNativeGridIdentity.d2.gridNumber == 47)
        #expect(IconNativeGridIdentity.d2.gridUUIDHex == "c6b12daa91ad64045b26c1b6452a2a20")
        #expect(IconNativeGridIdentity.d2.cellCount == 542_040)
        #expect(IconNativeGridIdentity.d2.maximumDistanceMeters == 4_000)

        let global = try #require(IconDomains.iconNative.nativeGridFile)
        let hourly = try #require(IconDomains.iconD2Native.nativeGridFile)
        let quarterHourly = try #require(IconDomains.iconD2Native15min.nativeGridFile)
        #expect(hourly.cache === quarterHourly.cache)
        #expect(global.cache !== hourly.cache)
        #expect(hourly.registry == .dwd_icon_d2_native)
    }

    @Test func gribGridValidation() throws {
        try metadata(identity: .d2).validate(identity: .d2)
        try IconNativeGribDecoder.validateDecodedValueCount(IconNativeGridIdentity.d2.cellCount, identity: .d2)

        #expect(throws: IconNativeGribError.self) {
            try metadata(identity: .global).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.self) {
            try metadata(identity: .d2, dataPointCount: 525_072).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.self) {
            try IconNativeGribDecoder.validateDecodedValueCount(525_072, identity: .d2)
        }
    }

    @Test(arguments: [
        (MultiDomains.dwd_icon_global_native, DomainRegistry.dwd_icon_global_native),
        (.dwd_icon_d2_native, .dwd_icon_d2_native),
        (.dwd_icon_d2_native_15min, .dwd_icon_d2_native_15min)
    ])
    func nativeApiModelRegistry(model: MultiDomains, registry: DomainRegistry) {
        #expect(model.getDomainAndVariable()?.singleDomain?.domainRegistry == registry)
    }

    private func metadata(
        identity: IconNativeGridIdentity,
        dataPointCount: Int? = nil
    ) -> IconNativeGribMetadata {
        IconNativeGribMetadata(
            edition: 2,
            gridType: "unstructured_grid",
            gridDefinitionTemplateNumber: 101,
            numberOfGridUsed: Int(identity.gridNumber),
            uuidOfHGrid: identity.gridUUIDHex,
            numberOfDataPoints: dataPointCount ?? identity.cellCount
        )
    }
}
