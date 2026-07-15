import Foundation
@testable import App
import Testing

@Suite struct IconNativeDomainTests {
    @Test func domainsKeepStorageAndDwdSourceIdentitySeparate() {
        #expect(IconDomains.iconNative.rawValue == "icon-native")
        #expect(IconDomains.iconNative.domainRegistry == .dwd_icon_global_native)
        #expect(IconDomains.iconNative.sourceDomain == .icon)
        #expect(IconDomains.iconNative.region == "global")

        #expect(IconDomains.iconD2Native.rawValue == "icon-d2-native")
        #expect(IconDomains.iconD2Native.domainRegistry == .dwd_icon_d2_native)
        #expect(IconDomains.iconD2Native.sourceDomain == .iconD2)
        #expect(IconDomains.iconD2Native.region == "germany")
        #expect(IconDomains.iconD2Native.fifteenMinuteDomain == .iconD2Native15min)
        #expect(IconDomains.iconD2Native15min.domainRegistryStatic == .dwd_icon_d2_native)
        #expect(IconDomains.iconD2Native15min.dtSeconds == 900)
    }

    @Test func nativeDomainsMirrorSourceForecastStepsAndLevels() {
        for run in [0, 6, 12, 18] {
            #expect(IconDomains.iconNative.getDownloadForecastSteps(run: run) == IconDomains.icon.getDownloadForecastSteps(run: run))
            #expect(IconDomains.iconD2Native.getDownloadForecastSteps(run: run) == IconDomains.iconD2.getDownloadForecastSteps(run: run))
        }
        #expect(IconDomains.iconNative.levels == IconDomains.icon.levels)
        #expect(IconDomains.iconD2Native.levels == IconDomains.iconD2.levels)
        #expect(IconDomains.iconD2Native15min.levels.isEmpty)
    }

    @Test func globalDownloadAliasesProduceNativeAndRemappedDomainsTogether() {
        let regular = IconDomains.icon.downloadDomains
        let native = IconDomains.iconNative.downloadDomains

        #expect(regular == native)
        #expect(regular == [.iconNative, .icon])

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
        #expect(IconNativeGridIdentity.global.sourceUrl.hasSuffix("/icon_grid_0026_R03B07_G.nc.bz2"))
        #expect(IconNativeGridIdentity.d2.sourceUrl.hasSuffix("/icon_grid_0047_R19B07_L.nc.bz2"))
    }

    @Test func netcdfConnectivityIsTransposedAndConvertedToNativeIndices() throws {
        let missing: Int32 = -1
        // NetCDF stores the three neighbour planes as (nv, cell), while the artifact is cell-major.
        let netcdf: [Int32] = [
            2, 1, 2,
            3, 3, 1,
            missing, missing, missing,
        ]
        let actual = try IconNativeGridGenerator.transposeConnectivity(
            netcdf,
            cellCount: 3,
            upperBound: 3,
            variable: "neighbor_cell_index",
            allowsMissing: true
        )

        #expect(actual == [
            1, 2, IconNativeGrid.missingIndex,
            0, 2, IconNativeGrid.missingIndex,
            1, 0, IconNativeGrid.missingIndex,
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
        let global = try #require(MultiDomains.dwd_icon_global_native.getDomainAndVariable())
        guard case .single(let globalDomain, let globalVariable) = global else {
            Issue.record("Expected a single generic global native domain")
            return
        }
        #expect(globalDomain as? IconDomains == .iconNative)
        #expect(ObjectIdentifier(globalVariable) == ObjectIdentifier(IconVariable.self))

        let d2 = try #require(MultiDomains.dwd_icon_d2_native.getDomainAndVariable())
        guard case .multiple(let domains) = d2 else {
            Issue.record("Expected generic hourly and 15-minute D2 native domains")
            return
        }
        #expect(domains.compactMap { $0.0 as? IconDomains } == [.iconD2Native, .iconD2Native15min])

        let d2FifteenMinute = try #require(MultiDomains.dwd_icon_d2_native_15min.getDomainAndVariable())
        guard case .single(let d2FifteenMinuteDomain, let d2FifteenMinuteVariable) = d2FifteenMinute else {
            Issue.record("Expected a single generic 15-minute native domain")
            return
        }
        #expect(d2FifteenMinuteDomain as? IconDomains == .iconD2Native15min)
        #expect(ObjectIdentifier(d2FifteenMinuteVariable) == ObjectIdentifier(IconVariable.self))
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
