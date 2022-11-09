import Foundation
import Vapor


/**
 Automatic domain selection rules:
 - If HRRR domain matches, use HRRR+GFS+ICON
 - If Western Europe, use Arome + ICON_EU+ ICON + GFS
 - If Central Europe, use ICON_D2, ICON_EU, ICON + GFS
 - If Japan, use JMA_MSM + ICON + GFS
 - default ICON + GFS
 */
enum MultiDomains: String, Codable, CaseIterable {
    case auto

    case gfs_mix
    case gfs_global
    case gfs_hrrr
    
    case meteofrance_mix
    case meteofrance_arpege_world
    case meteofrance_arpege_europe
    case meteofrance_arome_france
    case meteofrance_arome_france_hd
    
    case jma_mix
    case jma_msm
    case jms_gsm
    
    case icon_mix
    case icon_global
    case icon_eu
    case icon_d2
    
    case ecmwf_ifs04
    
    /// Return the required readers for this domain configuration
    /// Note: last reader has highes resolution data
    fileprivate func getReader(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> [any GenericReaderMixerForecast] {
        switch self {
        case .auto:
            guard let icon: GenericReaderMixerForecast = try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            guard let gfs025: GenericReaderMixerForecast = try GfsReader(domain: .gfs025, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
            }
            // If Icon-d2 is available, use icon domains
            if let iconD2 = try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                // TODO: check how out of projection areas are handled
                guard let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    throw ModelError.domainInitFailed(domain: IconDomains.icon.rawValue)
                }
                return [gfs025, icon, iconEu, iconD2]
            }
            // For western europe, use arome models
            if let arome_france_hd = try MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                let arome_france = try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode)
                let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode)
                return Array([gfs025, icon, arpege_europe, arome_france, arome_france_hd].compacted())
            }
            // For North America, use HRRR
            if let hrrr = try GfsReader(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [icon, gfs025, hrrr]
            }
            // For Japan use JMA MSM with ICON. Does not use global JMA model because of poor resolution
            if let jma_msm = try JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, jma_msm]
            }
            
            // Remaining eastern europe
            if let iconEu = try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, iconEu]
            }
            
            // Northern africa
            if let arpege_europe = try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode) {
                return [gfs025, icon, arpege_europe]
            }
            
            // Remaining parts of the world
            return [gfs025, icon]
        case .gfs_mix:
            return try GfsMixer(domains: [.gfs025, .hrrr_conus], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .gfs_global:
            return try GfsReader(domain: .gfs025, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .gfs_hrrr:
            return try GfsReader(domain: .hrrr_conus, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_mix:
            return try MeteoFranceMixer(domains: [.arpege_world, .arpege_europe, .arome_france, .arome_france_hd], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .meteofrance_arpege_world:
            return try MeteoFranceReader(domain: .arpege_world, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arpege_europe:
            return try MeteoFranceReader(domain: .arpege_europe, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arome_france:
            return try MeteoFranceReader(domain: .arome_france, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .meteofrance_arome_france_hd:
            return try MeteoFranceReader(domain: .arome_france_hd, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .jma_mix:
            return try JmaMixer(domains: [.msm, .gsm], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .jma_msm:
            return try JmaReader(domain: .msm, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .jms_gsm:
            return try JmaReader(domain: .gsm, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_mix:
            return try IconMixer(domains: [.iconD2, .iconEu, .icon], lat: lat, lon: lon, elevation: elevation, mode: mode)?.reader ?? []
        case .icon_global:
            return try IconReader(domain: .icon, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_eu:
            return try IconReader(domain: .iconEu, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .icon_d2:
            return try IconReader(domain: .iconD2, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        case .ecmwf_ifs04:
            return try EcmwfReader(domain: .ifs04, lat: lat, lon: lon, elevation: elevation, mode: mode).flatMap({[$0]}) ?? []
        }
    }
}

/// Define functions to read data for mixing. Similar to `GenericReaderMixer` but with optional `get` and without any generic constraints
fileprivate protocol GenericReaderMixerForecast {
    func get(mixed: ForecastVariable, time: TimerangeDt) throws -> DataAndUnit?
    func prefetchData(mixed: ForecastVariable, time: TimerangeDt) throws -> Bool
    
    var modelLat: Float { get }
    var modelLon: Float { get }
    var targetElevation: Float { get }
    var modelDtSeconds: Int { get }
}

/// Conditional conformace just use RawValue (String) to resolve `ForecastVariable` to a specific type
extension GenericReaderMixable where MixingVar: RawRepresentable, MixingVar.RawValue == String {
    func get(mixed: ForecastVariable, time: TimerangeDt) throws -> DataAndUnit? {
        guard let v = MixingVar(rawValue: mixed.rawValue) else {
            return nil
        }
        return try self.get(variable: v, time: time)
    }
    
    func prefetchData(mixed: ForecastVariable, time: TimerangeDt) throws -> Bool {
        guard let v = MixingVar(rawValue: mixed.rawValue) else {
            return false
        }
        try self.prefetchData(variable: v, time: time)
        return true
    }
}


extension GfsReader: GenericReaderMixerForecast { }
extension IconReader: GenericReaderMixerForecast { }
extension MeteoFranceReader: GenericReaderMixerForecast { }
extension JmaReader: GenericReaderMixerForecast { }
extension EcmwfReader: GenericReaderMixerForecast { }

/// Combine multiple independent weahter models, that may not have given forecast variable
struct MultiDomainMixer {
    private let reader: [any GenericReaderMixerForecast]
    
    let domain: MultiDomains
    
    var modelLat: Float {
        reader.last!.modelLat
    }
    var modelLon: Float {
        reader.last!.modelLon
    }
    var targetElevation: Float {
        reader.last!.targetElevation
    }
    var modelDtSeconds: Int {
        reader.first!.modelDtSeconds
    }
    
    public init?(domain: MultiDomains, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        let reader = try domain.getReader(lat: lat, lon: lon, elevation: elevation, mode: mode)
        guard !reader.isEmpty else {
            return nil
        }
        self.domain = domain
        self.reader = reader
    }
    
    func prefetchData(variable: ForecastVariable, time: TimerangeDt) throws {
        for reader in reader {
            if try reader.prefetchData(mixed: variable, time: time) {
                break
            }
        }
    }
    
    func prefetchData(variables: [ForecastVariable], time: TimerangeDt) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
    
    func get(variable: ForecastVariable, time: TimerangeDt) throws -> DataAndUnit {
        /// Last reader return highest resolution data
        guard let highestResolutionData = try reader.last?.get(mixed: variable, time: time) else {
            fatalError()
        }
        if !highestResolutionData.data.containsNaN() {
            return highestResolutionData
        }
        
        // Integrate now lower resolution models
        var data = highestResolutionData.data
        if variable.requiresOffsetCorrectionForMixing {
            data.deltaEncode()
            for r in reader.reversed().dropFirst() {
                guard let d = try r.get(mixed: variable, time: time) else {
                    continue
                }
                data.integrateIfNaNDeltaCoded(d.data)
                
                if !data.containsNaN() {
                    break
                }
            }
            // undo delta operation
            data.deltaDecode()
            return DataAndUnit(data, highestResolutionData.unit)
        }
        
        // default case, just place new data in 1:1
        for r in reader.reversed() {
            guard let d = try r.get(mixed: variable, time: time) else {
                continue
            }
            data.integrateIfNaN(d.data)
            
            if !data.containsNaN() {
                break
            }
        }
        return DataAndUnit(data, highestResolutionData.unit)
    }
}

enum ModelError: AbortError {
    var status: NIOHTTP1.HTTPResponseStatus {
        return .badRequest
    }
    
    case domainInitFailed(domain: String)
}
