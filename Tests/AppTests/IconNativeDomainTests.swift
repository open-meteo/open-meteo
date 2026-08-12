import Foundation
@testable import App
import Testing

@Suite struct IconNativeDomainTests {
    @Test func nativeDomainMappings() {
        #expect(IconDomains.iconNative.domainRegistry == .dwd_icon_global_native)
        #expect(IconDomains.iconNative.sourceDomain == .icon)
        #expect(IconDomains.iconD2Native.domainRegistry == .dwd_icon_d2_native)
        #expect(IconDomains.iconD2Native.sourceDomain == .iconD2)
        #expect(IconDomains.iconD2Native.fifteenMinuteDomain == .iconD2Native15min)
        #expect(IconDomains.iconD2Native15min.domainRegistryStatic == .dwd_icon_d2_native)
        #expect(IconDomains.icon.downloadDomains == [.iconNative, .icon])
        #expect(IconDomains.iconNative.downloadDomains == [.iconNative, .icon])
        #expect(IconDomains.iconD2.downloadDomains == [.iconD2])
        #expect(IconDomains.iconD2Native.downloadDomains == [.iconD2Native])
    }

    @Test func globalRemappingGathersNativeCellsAndPreservesMissingDestinations() {
        let remapper = CdoIconGlobal(mapping: [2, -1, 0, 2])
        let remapped = remapper.remap([10, 20, 30])

        #expect(remapped[0] == 30)
        #expect(remapped[1].isNaN)
        #expect(remapped[2] == 10)
        #expect(remapped[3] == 30)
    }

    @Test func nativeGridIdentitiesMatchOperationalGrids() {
        #expect(IconNativeGridIdentity.global.gridNumber == 26)
        #expect(IconNativeGridIdentity.global.gridUUIDHex == "a27b8de618c411e4820ab5b098c6a5c0")
        #expect(IconNativeGridIdentity.global.cellCount == 2_949_120)
        #expect(IconNativeGridIdentity.global.maximumDistanceMeters == 20_000)
        #expect(IconNativeGridIdentity.d2.gridNumber == 47)
        #expect(IconNativeGridIdentity.d2.gridUUIDHex == "c6b12daa91ad64045b26c1b6452a2a20")
        #expect(IconNativeGridIdentity.d2.cellCount == 542_040)
        #expect(IconNativeGridIdentity.d2.maximumDistanceMeters == 4_000)
    }

    @Test func gribMetadataMatchesGridIdentityAndCount() throws {
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

    @Test func forecastModelsUseGenericDomainMappings() throws {
        #expect(try mappedIconDomains(.dwd_icon_global_native) == [.iconNative])
        #expect(try mappedIconDomains(.dwd_icon_d2_native) == [.iconD2Native, .iconD2Native15min])
        #expect(try mappedIconDomains(.dwd_icon_d2_native_15min) == [.iconD2Native15min])
    }

    private func mappedIconDomains(_ model: MultiDomains) throws -> [IconDomains] {
        switch try #require(model.getDomainAndVariable()) {
        case .single(let domain, _):
            return [try #require(domain as? IconDomains)]
        case .multiple(let domains):
            return domains.compactMap { $0.0 as? IconDomains }
        default:
            Issue.record("Expected a single or multiple native ICON mapping")
            return []
        }
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
