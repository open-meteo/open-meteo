import Foundation
import OmFileFormat

/**
 Group all probabilities variables for all domains in one enum
 */
enum ProbabilityVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case precipitation_probability

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        return 1
    }

    var interpolation: ReaderInterpolation {
        return .hermite(bounds: 0...100)
    }

    var unit: SiUnit {
        return .percentage
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return false
    }
}

/**
 Create readers for various models
 */
enum ProbabilityReader {
    /// Read probabilities from GFS ensemble models 0.25° and 0.5°
    static func makeGfsReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReaderMixerSameVariableType<GenericReader<GfsDomain, ProbabilityVariable>>? {
        let readers: [GenericReader<GfsDomain, ProbabilityVariable>] = try await [GfsDomain.gfs05_ens, .gfs025_ens].asyncCompactMap { domain in
            do {
                return try await GenericReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
            } catch ForecastApiError.modelRunUnavailable {
                return nil
            }
        }
        return readers.isEmpty ? nil : GenericReaderMixerSameVariableType(reader: readers)
    }

    /// Notes: Does not use ICON-D2, because it has fewer members. It need some kind of mixing
    static func makeIconReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> ReaderComposition {
        let source = try await MultiDomains.iconProbabilitySource()
        do {
            return try await source.bind(.init(latitude: lat, longitude: lon, elevation: elevation, mode: mode, elevationPolicy: .independentSources), options: options)
                ?? .mix([], smoothTransitions: true)
        } catch ForecastApiError.modelRunUnavailable {
            // Probability sources are optional even for explicitly selected runs.
            return .mix([], smoothTransitions: true)
        }
    }

    /// Reader for probabilities based on NCEP NBM
    static func makeNbmReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReader<NbmDomain, ProbabilityVariable>? {
        do {
            return try await GenericReader<NbmDomain, ProbabilityVariable>(domain: .nbm_conus, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        } catch ForecastApiError.modelRunUnavailable {
            return nil
        }
    }

    /// Reader for probabilities based on MeteoFrance ARPEGE Europe 0.1°
//    static func makeMeteoFranceEuropeReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReader<MeteoFranceDomain, ProbabilityVariable>? {
//        return try await GenericReader<MeteoFranceDomain, ProbabilityVariable>(domain: .arpege_europe_probabilities, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
//    }

    /// Reader for probabilities based on AIGEFS
    static func makeAigefsReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReader<GfsGraphCastDomain, ProbabilityVariable>? {
        return try await GenericReader<GfsGraphCastDomain, ProbabilityVariable>(domain: .aigfs025, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }

    /// Reader for probabilities based on BOM ACCESS GLOBAL ENSEMBLE
    static func makeBomReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReader<BomDomain, ProbabilityVariable> {
        guard let reader = try await GenericReader<BomDomain, ProbabilityVariable>(domain: .access_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            throw ModelError.domainInitFailed(domain: BomDomain.access_global_ensemble.rawValue)
        }
        return reader
    }

    /// Reader for probabilities based on IFS0.25 ensemble
    static func makeEcmwfReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GenericReader<EcmwfDomain, ProbabilityVariable>? {
        do {
            return try await GenericReader<EcmwfDomain, ProbabilityVariable>(domain: .ifs025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
        } catch ForecastApiError.modelRunUnavailable {
            return nil
        }
    }
}

extension VariablePerMemberStorage {
    /// Calculate precipitation >0.1mm/h probability
    /// `precipitationVariable` is used to filter only precipitation variables
    /// `writer` produces the temporary file handle afterwards
    /// `dtHoursOfCurrentStep` should be set to the correct delta time in hours for this timestep if the step width changes. E.g. 3 to 6 hours after 120h. If no dt switching takes place, just use `domain.dtHours`.
    func calculatePrecipitationProbability(precipitationVariable: V, dtHoursOfCurrentStep: Int, writer: OmSpatialTimestepWriter) async throws {
        // Usefull probs, precip >0.1, >1, clouds <20%, clouds 20-50, 50-80, >80, snowfall eq >0.1, >1.0, wind >20kt, temp <0, temp >25
        // However, more and more probabilities takes up more resources than analysing raw member data
        let handles = self.data.filter({ $0.key.variable == precipitationVariable })
        let nMember = handles.count
        guard nMember > 1, dtHoursOfCurrentStep > 0 else {
            //print("skip nMember=\(nMember), dtHoursOfCurrentStep=\(dtHoursOfCurrentStep)")
            return
        }

        var precipitationProbability01 = [Float](repeating: 0, count: handles.first!.value.data.count)
        let threshold = Float(0.1) * Float(dtHoursOfCurrentStep)
        for (v, data) in handles {
            guard v.variable == precipitationVariable else {
                continue
            }
            for i in data.data.indices {
                if data.data[i] >= threshold {
                    precipitationProbability01[i] += 1
                }
            }
        }
        precipitationProbability01.multiplyAdd(multiply: 100 / Float(nMember), add: 0)
        return try await writer.write(member: 0, variable: ProbabilityVariable.precipitation_probability, data: precipitationProbability01)
    }
}
