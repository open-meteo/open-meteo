import Foundation
@preconcurrency import SwiftEccodes

/// NOAA's inventory distinguishes fields which share GRIB short names (and includes
/// the statistical interval in minutes for subhourly files).
struct NcepRrfsRecord: Sendable {
    let variable: String
    let parameter: String
    let startMinute: Int
    let endMinute: Int
    let stepType: String

    var field: NcepRrfsField? { NcepRrfsField(rawValue: variable) }
    var isSolarRadiation: Bool { parameter == "DSWRF" || parameter == "VDDSF" }
    var requiresSolarBackwardsConversion: Bool { isSolarRadiation && stepType == "instant" }
    var isWind: Bool { parameter == "UGRD" || parameter == "VGRD" }
    var isStatic: Bool { variable == "elevation" || variable == "landmask" }

    func convertUnits(data: inout [Float]) {
        if ["TMP", "DPT", "TSOIL"].contains(parameter) { data.multiplyAdd(multiply: 1, add: -273.15) }
        if variable == "pressure_msl" || variable == "surface_pressure" { data.multiplyAdd(multiply: 0.01, add: 0) }
        if variable == "snowfall" { data.multiplyAdd(multiply: 100, add: 0) }
        // NOAA reports negative CIN; Open-Meteo stores its positive magnitude.
        if variable == "convective_inhibition" { data.multiplyAdd(multiply: -1, add: 0) }
    }

    static func parse(_ line: String, domain: NcepRrfsDomain, pressureFile: Bool) throws -> Self? {
        let parts = line.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 6, Int(parts[0]) != nil, Int(parts[1]) != nil else {
            throw NcepRrfsError.invalidInventory(line)
        }
        let parameter = String(parts[3]), level = String(parts[4]), step = String(parts[5])
        let stepType = step.contains("acc fcst") ? "accum" : step.contains("ave fcst") ? "avg" : "instant"
        let isExtremum = step.split(separator: " ").count >= 4 && (step.contains("max fcst") || step.contains("min fcst"))
        if isExtremum || line.contains("prob fcst") { return nil }
        let start: Int, end: Int
        if step == "anl" {
            start = 0; end = 0
        } else {
            let time = step.split(separator: " ")
            guard time.count >= 3, ["min", "hour", "day"].contains(time[1]) else {
                throw NcepRrfsError.invalidInventory(line)
            }
            let interval = time[0].split(separator: "-")
            guard let last = interval.last.flatMap({ Int($0) }), let first = interval.first.flatMap({ Int($0) }) else {
                throw NcepRrfsError.invalidInventory(line)
            }
            let multiplier = time[1] == "day" ? 1440 : time[1] == "hour" ? 60 : 1
            start = first * multiplier; end = last * multiplier
        }
        if stepType != "instant" && start == end { return nil }
        let name: String
        if pressureFile {
            guard level.hasSuffix(" mb"), let pressure = Int(level.split(separator: " ")[0]), pressure >= 50 else { return nil }
            let names = ["TMP": "temperature", "RH": "relative_humidity", "HGT": "geopotential_height", "UGRD": "wind_speed", "VGRD": "wind_speed", "DZDT": "vertical_velocity"]
            guard let prefix = names[parameter] else { return nil }
            name = "\(prefix)_\(pressure)hPa"
        } else if ["UGRD", "VGRD", "TMP"].contains(parameter),
                  level.hasSuffix(" m above ground") || level.hasSuffix(" m above mean sea level"),
                  let height = Int(level.split(separator: " ")[0]) {
            name = "\(parameter == "TMP" ? "temperature" : "wind_speed")_\(height)m"
        } else if ["TSOIL", "SOILW"].contains(parameter), level.hasSuffix(" m below ground") {
            let depths = level.split(separator: " ")[0].split(separator: "-")
            guard depths.count == 2, depths[0] == depths[1], let depth = Float(depths[0]) else { return nil }
            name = "soil_\(parameter == "TSOIL" ? "temperature" : "moisture")_\(Int((depth * 100).rounded()))cm"
        } else if parameter == "DPT", level == "2 m above ground", domain == .ncep_rrfs_conus_15min {
            name = "dewpoint_2m" // converted to RH together with temperature
        } else {
            let mapping = [
                "HGT:surface": "elevation", "LAND:surface": "landmask",
                "TMP:surface": "surface_temperature", "RH:2 m above ground": "relative_humidity_2m",
                "MSLET:mean sea level": "pressure_msl", "PRES:surface": "surface_pressure",
                "GUST:surface": "wind_gusts_10m", "VIS:surface": "visibility",
                "CPOFP:surface": "frozen_precipitation_percent",
                "TSNOWP:surface": "snowfall_water_equivalent",
                "APCP:surface": "precipitation", "ASNOW:surface": "snowfall", "SNOD:surface": "snow_depth",
                "CFRZR:surface": "categorical_freezing_rain", "CAPE:surface": "cape", "CIN:surface": "convective_inhibition",
                "HPBL:surface": "boundary_layer_height", "LFTX:500-1000 mb": "lifted_index",
                "PWAT:entire atmosphere (considered as a single layer)": "total_column_integrated_water_vapour",
                "TCDC:entire atmosphere (considered as a single layer)": "cloud_cover",
                "LCDC:low cloud layer": "cloud_cover_low", "MCDC:middle cloud layer": "cloud_cover_mid", "HCDC:high cloud layer": "cloud_cover_high",
                "HGT:0C isotherm": "freezing_level_height", "DSWRF:surface": "shortwave_radiation",
                "VDDSF:surface": "diffuse_radiation", "SHTFL:surface": "sensible_heat_flux", "LHTFL:surface": "latent_heat_flux"
            ]
            guard let mapped = mapping["\(parameter):\(level)"] else { return nil }
            name = mapped
        }
        if ["elevation", "landmask", "dewpoint_2m", "frozen_precipitation_percent"].contains(name) {
            return Self(variable: name, parameter: parameter, startMinute: start, endMinute: end, stepType: stepType)
        }
        if pressureFile {
            let supported = domain == .ncep_rrfs_conus_ensemble
                ? NcepRrfsEnsemblePressureVariable(rawValue: name) != nil
                : NcepRrfsConusPressureVariable(rawValue: name) != nil
            guard supported else { return nil }
        }
        if !pressureFile {
            let supported: Bool
            switch domain {
            case .ncep_rrfs_conus: supported = NcepRrfsSurfaceVariable(rawValue: name) != nil
            case .ncep_rrfs_conus_15min: supported = NcepRrfs15MinVariable(rawValue: name) != nil
            case .ncep_rrfs_conus_ensemble: supported = NcepRrfsEnsembleSurfaceVariable(rawValue: name) != nil
            }
            guard supported else { return nil }
        }
        switch name {
        case "precipitation", "snowfall", "snowfall_water_equivalent": guard stepType == "accum" else { return nil }
        case "shortwave_radiation":
            guard stepType == (domain == .ncep_rrfs_conus_15min ? "instant" : "avg") else { return nil }
        case "latent_heat_flux", "sensible_heat_flux": guard stepType == "avg" else { return nil }
        default: guard stepType == "instant" else { return nil }
        }
        return Self(variable: name, parameter: parameter, startMinute: start, endMinute: end, stepType: stepType)
    }
}

enum NcepRrfsError: Error {
    case invalidInventory(String)
    case inventoryMessageCountMismatch
    case invalidTimestamp
    case missingElevation
    case emptySelection
    case incompleteWindPair(String)
}

/// Select required records for range downloads. The cursor also supports validating
/// local GRIB samples against their complete inventories.
actor NcepRrfsInventory {
    private let records: [NcepRrfsRecord?]
    private var offset = 0

    init(text: String, domain: NcepRrfsDomain, pressureFile: Bool) throws {
        var seen = Set<String>()
        records = try text.split(separator: "\n").map { line in
            guard let record = try NcepRrfsRecord.parse(String(line), domain: domain, pressureFile: pressureFile) else { return nil }
            let key = "\(record.variable)/\(record.endMinute)/\(record.isWind ? record.parameter : "")"
            return seen.insert(key).inserted ? record : nil
        }
        let selected = records.compactMap { $0 }
        guard !selected.isEmpty else { throw NcepRrfsError.emptySelection }
        for record in selected where record.isWind {
            let other = record.parameter == "UGRD" ? "VGRD" : "UGRD"
            guard seen.contains("\(record.variable)/\(record.endMinute)/\(other)") else {
                throw NcepRrfsError.incompleteWindPair(record.variable)
            }
        }
    }

    func next(_ message: GribMessage) throws -> (NcepRrfsRecord?, GribMessage) {
        guard offset < records.count else { throw NcepRrfsError.inventoryMessageCountMismatch }
        defer { offset += 1 }
        return (records[offset], message)
    }

    func validateComplete() throws {
        guard offset == records.count else { throw NcepRrfsError.inventoryMessageCountMismatch }
    }
}
