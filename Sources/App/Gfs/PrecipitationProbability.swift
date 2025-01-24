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
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Create readers for various models
 */
struct ProbabilityReader {
    /// Read probabilities from GFS ensemble models 0.25° and 0.5°
    static func makeGfsReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReaderMixerSameDomain<GenericReader<GfsDomain, ProbabilityVariable>> {
        return GenericReaderMixerSameDomain(reader: [
            try GenericReader<GfsDomain, ProbabilityVariable>(domain: .gfs05_ens, lat: lat, lon: lon, elevation: elevation, mode: mode),
            try GenericReader<GfsDomain, ProbabilityVariable>(domain: .gfs025_ens, lat: lat, lon: lon, elevation: elevation, mode: mode)
        ].compactMap({$0}))
    }
    
    /// Notes: Does not use ICON-D2, because it has fewer members. It need some kind of mixing
    static func makeIconReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReaderMixerSameDomain<GenericReader<IconDomains, ProbabilityVariable>> {
        return GenericReaderMixerSameDomain(reader: [
            try GenericReader<IconDomains, ProbabilityVariable>(domain: .iconEps, lat: lat, lon: lon, elevation: elevation, mode: mode),
            try GenericReader<IconDomains, ProbabilityVariable>(domain: .iconEuEps, lat: lat, lon: lon, elevation: elevation, mode: mode)
        ].compactMap({$0}))
    }
    
    /// Reader for probabilities based on ICON EPS
    static func makeIconGlobalReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<IconDomains, ProbabilityVariable> {
        guard let reader = try GenericReader<IconDomains, ProbabilityVariable>(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
        }
        return reader
    }
    
    /// Reader for probabilities based on NCEP NBM
    static func makeNbmReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<NbmDomain, ProbabilityVariable>? {
        return try GenericReader<NbmDomain, ProbabilityVariable>(domain: .nbm_conus, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
    
    /// Reader for probabilities based on MeteoFrance ARPEGE Europe 0.1°
    static func makeMeteoFranceEuropeReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<MeteoFranceDomain, ProbabilityVariable>? {
        return try GenericReader<MeteoFranceDomain, ProbabilityVariable>(domain: .arpege_europe_probabilities, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
    
    /// Reader for probabilities based on ICON EU EPS
    static func makeIconEuReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<IconDomains, ProbabilityVariable>? {
        return try GenericReader<IconDomains, ProbabilityVariable>(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
    
    /// Reader for probabilities based on ICON D2 EPS
    static func makeIconD2Reader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<IconDomains, ProbabilityVariable>? {
        return try GenericReader<IconDomains, ProbabilityVariable>(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
    
    /// Reader for probabilities based on BOM ACCESS GLOBAL ENSEMBLE
    static func makeBomReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<BomDomain, ProbabilityVariable> {
        guard let reader = try GenericReader<BomDomain, ProbabilityVariable>(domain: .access_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ModelError.domainInitFailed(domain: BomDomain.access_global_ensemble.rawValue)
        }
        return reader
    }
    
    /// Reader for probabilities based on GEM ENSEMBLE
    static func makeGemReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<GemDomain, ProbabilityVariable> {
        guard let reader = try GenericReader<GemDomain, ProbabilityVariable>(domain: .gem_global_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ModelError.domainInitFailed(domain: GemDomain.gem_global_ensemble.rawValue)
        }
        return reader
    }
    
    /// Reader for probabilities based on IFS0.25 ensemble
    static func makeEcmwfReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GenericReader<EcmwfDomain, ProbabilityVariable> {
        guard let reader = try GenericReader<EcmwfDomain, ProbabilityVariable>(domain: .ifs025_ensemble, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            throw ModelError.domainInitFailed(domain: EcmwfDomain.ifs025_ensemble.rawValue)
        }
        return reader
    }
}

extension VariablePerMemberStorage {
    /// Calculate precipitation >0.1mm/h probability
    /// `precipitationVariable` is used to filter only precipitation variables
    /// `domain` must be set to generate a temporary file handle afterwards
    /// `dtHoursOfCurrentStep` should be set to the correct delta time in hours for this timestep if the step width changes. E.g. 3 to 6 hours after 120h. If no dt switching takes place, just use `domain.dtHours`.
    func calculatePrecipitationProbability(precipitationVariable: V, domain: GenericDomain, timestamp: Timestamp, dtHoursOfCurrentStep: Int) throws -> GenericVariableHandle? {
        // Usefull probs, precip >0.1, >1, clouds <20%, clouds 20-50, 50-80, >80, snowfall eq >0.1, >1.0, wind >20kt, temp <0, temp >25
        // However, more and more probabilities takes up more resources than analysing raw member data
        let handles = self.data.filter({$0.key.variable == precipitationVariable})
        let nMember = handles.count
        guard nMember > 1, dtHoursOfCurrentStep > 0 else {
            print("skip nMember=\(nMember), dtHoursOfCurrentStep=\(dtHoursOfCurrentStep)")
            return nil
        }
        
        var precipitationProbability01 = [Float](repeating: 0, count: domain.grid.count)
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
        precipitationProbability01.multiplyAdd(multiply: 100/Float(nMember), add: 0)
        let variable = ProbabilityVariable.precipitation_probability
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: 1)
        let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: precipitationProbability01)
        return GenericVariableHandle(
            variable: variable,
            time: timestamp,
            member: 0,
            fn: fn
        )
    }
}

extension Array where Element == GenericVariableHandle {
    /// Calculate precipitation >0.1mm/h probability. BOM downloads multiple timesteps, uncompress handles and calculate probabilities
    /// `precipitationVariable` is used to filter only precipitation variables
    /// `domain` must be set to generate a temporary file handle afterwards
    func calculatePrecipitationProbabilityMultipleTimestamps(precipitationVariable: GenericVariable, domain: GenericDomain) throws -> [GenericVariableHandle] {
        var previousTimesamp: Timestamp? = nil
        return try self
            .filter({$0.variable.omFileName == precipitationVariable.omFileName})
            .groupedPreservedOrder(by: {$0.time})
            .sorted(by: {$0.key < $1.key})
            .compactMap({ (timestamp, handles) -> GenericVariableHandle? in
                let nMember = handles.count
                guard nMember > 1 else {
                    return nil
                }
                let dt = previousTimesamp.map { (timestamp.timeIntervalSince1970 - $0.timeIntervalSince1970) / 3600 } ?? domain.dtHours
                precondition(dt > 0, "dt <= 0")
                var precipitationProbability01 = [Float](repeating: 0, count: domain.grid.count)
                let threshold = Float(0.1) * Float(dt)
                for d in handles {
                    let reader = try d.makeReader()
                    for (i, value) in try reader.read().enumerated() {
                        if value >= threshold {
                            precipitationProbability01[i] += 1
                        }
                    }
                }
                previousTimesamp = timestamp
                precipitationProbability01.multiplyAdd(multiply: 100/Float(nMember), add: 0)
                let variable = ProbabilityVariable.precipitation_probability
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: 1)
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: precipitationProbability01)
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: 0,
                    fn: fn
                )
            })
    }
}
