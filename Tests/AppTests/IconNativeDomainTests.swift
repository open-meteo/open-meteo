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
        #expect(IconNativeGridIdentity.d2.gridNumber == 47)
        #expect(IconNativeGridIdentity.d2.gridUUIDHex == "c6b12daa91ad64045b26c1b6452a2a20")
        #expect(IconNativeGridIdentity.d2.cellCount == 542_040)
    }

    @Test func netcdfVertexConnectivityIsTransposedAndConvertedToNativeIndices() throws {
        // NetCDF stores three complete `(nv, cell)` planes; coverage construction uses cell-major
        // zero-based vertex triples.
        let netcdf: [Int32] = [
            2, 1, 2,
            3, 3, 1,
            1, 2, 3,
        ]
        let actual = try IconNativeGrid.Generator.transposeConnectivity(
            netcdf,
            cellCount: 3,
            upperBound: 3,
            variable: "vertex_of_cell"
        )

        #expect(actual == [
            1, 2, 0,
            0, 2, 1,
            1, 0, 2,
        ])
    }

    @Test func gribMetadataRequiresTheExactNativeGrid() throws {
        let valid = metadata(identity: .d2)
        try valid.validate(identity: .d2)

        #expect(throws: IconNativeGribError.invalidEdition(1)) {
            try metadata(identity: .d2, edition: 1).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.invalidGridType("regular_ll")) {
            try metadata(identity: .d2, gridType: "regular_ll").validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.invalidGridDefinitionTemplate(0)) {
            try metadata(identity: .d2, template: 0).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.invalidGridNumber(expected: 47, actual: 26)) {
            try metadata(identity: .d2, gridNumber: 26).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.invalidGridUUID(expected: IconNativeGridIdentity.d2.gridUUIDHex, actual: IconNativeGridIdentity.global.gridUUIDHex)) {
            try metadata(identity: .d2, uuid: IconNativeGridIdentity.global.gridUUIDHex).validate(identity: .d2)
        }
        #expect(throws: IconNativeGribError.invalidDataPointCount(expected: 542_040, actual: 525_072)) {
            try metadata(identity: .d2, dataPointCount: 525_072).validate(identity: .d2)
        }
    }

    @Test func decodedValuesMustIncludeBitmapMissingPositions() throws {
        try IconNativeGribDecoder.validateDecodedValueCount(IconNativeGridIdentity.d2.cellCount, identity: .d2)
        #expect(throws: IconNativeGribError.invalidDecodedValueCount(expected: 542_040, actual: 525_072)) {
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
        edition: Int? = 2,
        gridType: String? = "unstructured_grid",
        template: Int? = 101,
        gridNumber: Int? = nil,
        uuid: String? = nil,
        dataPointCount: Int? = nil
    ) -> IconNativeGribMetadata {
        IconNativeGribMetadata(
            edition: edition,
            gridType: gridType,
            gridDefinitionTemplateNumber: template,
            numberOfGridUsed: gridNumber ?? Int(identity.gridNumber),
            uuidOfHGrid: uuid ?? identity.gridUUIDHex,
            numberOfDataPoints: dataPointCount ?? identity.cellCount
        )
    }
}
