import Foundation

extension MultiDomains {
    /// One row of the `best_match` routing table.
    ///
    /// Rows are evaluated in order; the first row whose conditions all hold adds its regional
    /// readers on top of the global backbone. A contour limits a national model to its home
    /// area, so neighbours keep their own model where grids overlap. A box keeps a model away
    /// from its grid edge. `coverage` requires the coordinate to be inside a grid.
    struct BestMatchRegion: Sendable {
        typealias Sources = (primary: [DomainReaderMapping.Source], secondary: [DomainReaderMapping.Source])

        let name: String
        let contour: GeoContour?
        let box: (latitude: Range<Float>, longitude: Range<Float>)?
        let coverage: (any GenericDomain)?
        /// Readers in addition to the backbone, ordered lowest to highest priority. Secondary
        /// sources supply precipitation probabilities.
        let sources: @Sendable (_ include15Min: Bool) async throws -> Sources

        init(
            _ name: String,
            contour: GeoContour? = nil,
            box: (latitude: Range<Float>, longitude: Range<Float>)? = nil,
            coverage: (any GenericDomain)? = nil,
            sources: @escaping @Sendable (_ include15Min: Bool) async throws -> Sources
        ) {
            self.name = name
            self.contour = contour
            self.box = box
            self.coverage = coverage
            self.sources = sources
        }

        /// Cheapest condition first: box, contour (bounding box, then edges), grid projection.
        func contains(lat: Float, lon: Float) -> Bool {
            if let box, !(box.latitude.contains(lat) && box.longitude.contains(lon)) {
                return false
            }
            if let contour, !contour.contains(latitude: lat, longitude: lon) {
                return false
            }
            if let coverage, coverage.grid.findPoint(lat: lat, lon: lon) == nil {
                return false
            }
            return true
        }
    }

    /// Rectangle around the British Isles with the English Channel triangle cut out of its
    /// south-eastern corner, so the Belgian and northern French coast stay off UKMO. Unlike
    /// the national outlines it reaches into the North Sea and over Shetland, where UKMO is
    /// preferred to MET Nordic.
    private static let unitedKingdomAndIreland = GeoContour(flatRings: [
        [-11, 49.9, -0.2, 49.9, 1.8, 51.1, 1.8, 61, -11, 61]
    ])

    /// The `best_match` routing table. UKMO keeps its rectangle first, so no coastal buffer of a
    /// neighbour reaches into it. National models serve their home countries; ICON D2 serves the
    /// rest of its area, including Austria, Czechia, Denmark, northern Italy, southern Sweden and
    /// Switzerland, so only France overlaps it with its own model (the Benelux and UK models
    /// already sit above ICON D2). GEM RDPS continues after HRRR's horizon; GEM HRDPS only serves
    /// where HRRR has no data. Boxes keep models away from their grid edges: MET Nordic north of
    /// 54.9°N, DMI between 44°N and 68°N (all of Iceland, about 2° inside the grid's northern edge
    /// near 70°N) and west of Denmark's easternmost point, JMA MSM inside a rectangle around Japan.
    static let bestMatchRegions: [BestMatchRegion] = [
        BestMatchRegion("United Kingdom & Ireland", contour: unitedKingdomAndIreland, coverage: UkmoDomain.uk_deterministic_2km) { _ in
            let icon = await MultiDomains.iconEurope()
            return (
                icon.primary + [
                    .domain(UkmoDomain.global_deterministic_10km, SurfaceAndPressureVariable<UkmoGlobalDeterministicSurfaceVariable, UkmoPressureVariable>.self),
                    .domain(UkmoDomain.uk_deterministic_2km, UkmoVariable.self)
                ],
                icon.secondary + [
                    .domain(UkmoDomain.global_ensemble_20km, ProbabilityVariable.self),
                    .domain(UkmoDomain.uk_ensemble_2km, ProbabilityVariable.self)
                ]
            )
        },
        BestMatchRegion("France", contour: BestMatchContours.france, coverage: MeteoFranceDomain.arome_france_hd) { include15Min in
            let icon = await MultiDomains.iconCentralEurope(include15Min: include15Min)
            return (
                icon.primary + [
                    .domain(MeteoFranceDomain.arpege_europe, MeteoFranceVariable.self),
                    .domain(MeteoFranceDomain.arome_france, MeteoFranceVariable.self),
                    .domain(MeteoFranceDomain.arome_france_hd, MeteoFranceVariable.self),
                    .domain(MeteoFranceDomain.arome_france_15min, MeteoFranceVariable.self),
                    .domain(MeteoFranceDomain.arome_france_hd_15min, MeteoFranceVariable.self)
                ],
                icon.secondary
            )
        },
        BestMatchRegion("Benelux", contour: BestMatchContours.benelux, coverage: KnmiDomain.harmonie_arome_netherlands) { include15Min in
            let icon = await MultiDomains.iconCentralEurope(include15Min: include15Min)
            return (
                icon.primary + [
                    .domain(KnmiDomain.harmonie_arome_europe, KnmiVariable.self),
                    .domain(KnmiDomain.harmonie_arome_netherlands, KnmiVariable.self)
                ],
                icon.secondary
            )
        },
        BestMatchRegion("Central Europe", coverage: IconDomains.iconD2) { include15Min in
            await MultiDomains.iconCentralEurope(include15Min: include15Min)
        },
        BestMatchRegion("Norway, Sweden & Finland", contour: BestMatchContours.nordic, coverage: MetNoDomain.nordic_pp) { _ in
            let icon = await MultiDomains.iconEurope()
            return (icon.primary + [.domain(MetNoDomain.nordic_pp, MetNoVariable.self)], icon.secondary)
        },
        BestMatchRegion("Baltic Sea region", box: (latitude: 54.9..<90, longitude: -180..<180), coverage: MetNoDomain.nordic_pp) { _ in
            let icon = await MultiDomains.iconEurope()
            return (icon.primary + [.domain(MetNoDomain.nordic_pp, MetNoVariable.self)], icon.secondary)
        },
        BestMatchRegion("North Atlantic & North Sea", box: (latitude: 44..<68, longitude: -180..<15.2), coverage: DmiDomain.harmonie_arome_europe) { _ in
            let icon = await MultiDomains.iconEurope()
            return (icon.primary + [.domain(DmiDomain.harmonie_arome_europe, DmiVariable.self)], icon.secondary)
        },
        BestMatchRegion("North America", coverage: GfsDomain.hrrr_conus) { include15Min in
            (
                [
                    .domain(GemDomain.gem_rdps_10km, GemVariable.self),
                    .mixedBeforeDerivation(MultiDomains.hrrrDerivationGroup(include15Min: include15Min))
                ],
                [.domain(NbmDomain.nbm_conus, ProbabilityVariable.self)]
            )
        },
        BestMatchRegion("Canada", coverage: GemDomain.gem_hrdps_continental) { _ in
            (
                [
                    .domain(GemDomain.gem_rdps_10km, GemVariable.self),
                    .domain(GemDomain.gem_hrdps_continental, GemVariable.self)
                ],
                [.domain(GemDomain.gem_global_ensemble, ProbabilityVariable.self)]
            )
        },
        // The RDPS grid also reaches across the Atlantic to western Europe; keep it on its own continent.
        BestMatchRegion("Northern North America", box: (latitude: -90..<90, longitude: -180..<(-25)), coverage: GemDomain.gem_rdps_10km) { _ in
            (
                [.domain(GemDomain.gem_rdps_10km, GemVariable.self)],
                [.domain(GemDomain.gem_global_ensemble, ProbabilityVariable.self)]
            )
        },
        // A rectangle around Japan keeps JMA MSM away from its grid edges; it also holds the Korean peninsula.
        BestMatchRegion("Japan", box: (latitude: 24..<46, longitude: 123..<147), coverage: JmaDomain.msm) { _ in
            MultiDomains.jmaMsm()
        },
        BestMatchRegion("Europe", coverage: IconDomains.iconEu) { _ in
            await MultiDomains.iconEurope()
        }
    ]

    /// The table row serving a coordinate, if any.
    static func bestMatchRegion(lat: Float, lon: Float) -> BestMatchRegion? {
        bestMatchRegions.first { $0.contains(lat: lat, lon: lon) }
    }

    /// Readers for `best_match`: the global backbone plus the regional models of the first
    /// matching table row, each group ordered lowest to highest priority.
    static func bestMatchMapping(lat: Float, lon: Float, include15Min: Bool) async throws -> DomainReaderMapping {
        let backbone = await bestMatchBackbone()
        let regional = try await bestMatchRegion(lat: lat, lon: lon)?.sources(include15Min) ?? (primary: [], secondary: [])
        return DomainReaderMapping(
            primary: backbone.primary + regional.primary,
            secondary: backbone.secondary + regional.secondary,
            requirePrimaryCoverage: true
        )
    }

    /// Readers every `best_match` request starts from: GFS, ICON and IFS with their ensemble
    /// probabilities.
    private static func bestMatchBackbone() async -> BestMatchRegion.Sources {
        let icon = await iconSources(.icon, native: .iconNative)
        return (
            [.mixedBeforeDerivation(gfsGlobalDerivationGroup)] + icon + [
                .domain(EcmwfDomain.ifs025, EcmwfIfsVariable.self),
                .domain(EcmwfEcpdsDomain.ifs, EcmwfEcdpsIfsVariable.self)
            ],
            [
                .domain(GfsDomain.gfs05_ens, ProbabilityVariable.self),
                .domain(GfsDomain.gfs025_ens, ProbabilityVariable.self),
                .domain(EcmwfDomain.ifs025_ensemble, ProbabilityVariable.self)
            ] + (await iconProbabilitySources(.iconEps, native: .iconEpsNative))
        )
    }

    /// Readers for one ICON domain: regular storage, then the native grid and its model levels
    /// on top, as `best_match` prefers native storage. A native grid that cannot be loaded is
    /// skipped so an API node without the grid file still answers.
    private static func iconSources(_ regular: IconDomains, native: IconNativeDomains) async -> [DomainReaderMapping.Source] {
        var sources: [DomainReaderMapping.Source] = [.domain(regular, IconVariable.self)]
        guard let grid = try? await native.load() else {
            return sources
        }
        sources.append(.domain(grid, IconVariable.self))
        if let modelLevel = native.modelLevelDomain, let grid = try? await modelLevel.load() {
            sources.append(.domain(grid, IconModelLevelVariable.self))
        }
        return sources
    }

    private static func iconProbabilitySources(_ regular: IconDomains, native: IconNativeDomains) async -> [DomainReaderMapping.Source] {
        var sources: [DomainReaderMapping.Source] = [.domain(regular, ProbabilityVariable.self)]
        if let grid = try? await native.load() {
            sources.append(.domain(grid, ProbabilityVariable.self))
        }
        return sources
    }

    /// ICON EU with ICON D2 on top, the 15-minutely D2 storage only when 15-minutely data is
    /// requested, and the hourly updated ICON D2 RUC above both where its native grid is available.
    private static func iconCentralEurope(include15Min: Bool) async -> BestMatchRegion.Sources {
        var primary = await iconSources(.iconEu, native: .iconEuNative)
        primary += await iconSources(.iconD2, native: .iconD2Native)
        if include15Min {
            primary.append(.domain(IconDomains.iconD2_15min, IconVariable.self))
            if let grid = try? await IconNativeDomains.iconD2Native15min.load() {
                primary.append(.domain(grid, IconVariable.self))
            }
        }
        if let ruc = try? await IconNativeDomains.iconD2RucNative.load(),
           let rucModelLevel = try? await IconNativeDomains.iconD2RucNativeModelLevel.load(),
           let ruc15min = try? await IconNativeDomains.iconD2RucNative15min.load() {
            primary.append(.mixedBeforeDerivation(RawReaderDerivationGroup(
                domains: [ruc, rucModelLevel, ruc15min], variableType: IconVariable.self, derivationDomain: ruc
            )))
        }
        var secondary = await iconProbabilitySources(.iconEuEps, native: .iconEuEpsNative)
        secondary += await iconProbabilitySources(.iconD2Eps, native: .iconD2EpsNative)
        return (primary, secondary)
    }

    private static func iconEurope() async -> BestMatchRegion.Sources {
        (await iconSources(.iconEu, native: .iconEuNative), await iconProbabilitySources(.iconEuEps, native: .iconEuEpsNative))
    }

    private static func jmaMsm() -> BestMatchRegion.Sources {
        (
            [
                .domain(JmaDomain.msm_upper_level, JmaPressureVariable.self),
                .domain(JmaDomain.msm, JmaSurfaceVariable.self)
            ],
            []
        )
    }
}
