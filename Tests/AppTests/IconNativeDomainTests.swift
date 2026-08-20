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
        switch try #require(MultiDomains.dwd_icon_global_native.getDomainAndVariable()) {
        case .singleWithPrecipitationProbability(let domain, _, let precipitationProbability):
            #expect(try #require(domain as? IconDomains) == .iconNative)
            #expect(try #require(precipitationProbability as? IconDomains) == .iconEps)
        default:
            Issue.record("Expected native ICON global with precipitation probability")
        }

        switch try #require(MultiDomains.dwd_icon_d2_native.getDomainAndVariable()) {
        case .singleWithSupplementalDomains(let domain, _, _, let higher, let precipitationProbability):
            #expect(try #require(domain as? IconDomains) == .iconD2Native)
            #expect(higher.compactMap { $0.0 as? IconDomains } == [.iconD2Native15min])
            #expect(try #require(precipitationProbability as? IconDomains) == .iconD2Eps)
        default:
            Issue.record("Expected native ICON-D2 with supplemental 15-minute data and precipitation probability")
        }

        switch try #require(MultiDomains.dwd_icon_d2_native_15min.getDomainAndVariable()) {
        case .single(let domain, _):
            #expect(try #require(domain as? IconDomains) == .iconD2Native15min)
        default:
            Issue.record("Expected native ICON-D2 15-minute domain")
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
