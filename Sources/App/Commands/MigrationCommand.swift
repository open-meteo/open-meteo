import Foundation
import Vapor

/**
 Migrate the local open-meteo database to a new structure.
 See: https://github.com/open-meteo/open-meteo/pull/543
 
 Old `omfile-icon_d2/temperature_2m_12345.om`
 New `dwd_icon_d2/temperature_2m/chunk_12345.om`
 */
struct MigrationCommand: Command {
    struct Signature: CommandSignature {
        @Flag(name: "execute", help: "Perform file moves")
        var execute: Bool
    }
    
    var help: String {
        "Perform database migration"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        // loop over data directory
        let execute = signature.execute
        
        let pathUrl = URL(fileURLWithPath: OpenMeteo.dataDirectory, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
            fatalError("No files in \(pathUrl)")
        }
        
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  let isDirectory = resourceValues.isDirectory,
                  let name = resourceValues.name, 
                  !name.contains("~"),
                  isDirectory
            else {
                continue
            }
            
            if name.starts(with: "omfile-") || name.starts(with: "archive-") || name.starts(with: "master-")  || name.starts(with: "yearly-") {
                //print("found \(name)")
                let domainRaw = String(name.split(separator: "-", maxSplits: 1)[1])
                if domainRaw == "FGOALS_f3_H_highresSST" || domainRaw == "HadGEM3_GC31_HM" {
                    continue
                }
                var domain = domainRename(domainRaw)
                let domainFrom = "\(OpenMeteo.dataDirectory)\(name)"
                let subPath = "\(OpenMeteo.dataDirectory)\(name)"
                
                guard let directoryEnumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: subPath, isDirectory: true), includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else {
                    fatalError("No files in \(pathUrl)")
                }
                for case let fileURL as URL in directoryEnumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          let isDirectory = resourceValues.isDirectory,
                          let file = resourceValues.name,
                          !file.contains("~"),
                          !isDirectory
                    else {
                        continue
                    }
                    
                    //print("found file \(file)")
                    let type: String
                    if name.starts(with: "omfile-") {
                        type = "chunk"
                    } else if name.starts(with: "archive-") || name.starts(with: "yearly-") {
                        type = "year"
                    } else if name.starts(with: "master-") {
                        type = "master"
                    } else {
                        continue
                    }
                    
                    guard let new = transform(file: file, type: type) else {
                        continue
                    }
                    if new.file.contains("bias_linear") {
                        if domain == .copernicus_era5 {
                            domain = .copernicus_era5_daily
                        }
                        if domain == .copernicus_era5_land {
                            domain = .copernicus_era5_land_daily
                        }
                    }
                    let domainDirectory = "\(OpenMeteo.dataDirectory)\(domain.rawValue)"
                    let from = "\(domainFrom)/\(file)"
                    let to = "\(domainDirectory)/\(new.directory)/\(new.file)"
                    print("Move \(from) to \(to)")
                    if execute {
                        try FileManager.default.createDirectory(atPath: "\(domainDirectory)/\(new.directory)/", withIntermediateDirectories: true)
                        try FileManager.default.moveFileOverwrite(from: from, to: to)
                    }
                    
                }
                
                // create domain directory
                // loop over omfile-content
                // move Hsurf + soil
                // move create variables directory, move time chunks
            }
        }
        
    }
    
    /// Rename old domain names to new names
    func domainRename(_ domain: String) -> DomainRegistry {
        switch domain {
        case "msm":
            return .jma_msm
        case "gsm":
            return .jma_gsm
        case "gwam":
            return .dwd_gwam
        case "ewam":
            return .dwd_ewam
        case "ncep":
            return .ncep_cfsv2
        case "CMCC_CM2_VHR4":
            return .cmip_CMCC_CM2_VHR4
        case "EC_Earth3P_HR":
            return .cmip_EC_Earth3P_HR
        case "FGOALS_f3_H":
            return .cmip_FGOALS_f3_H
        case "HiRAM_SIT_HR":
            return .cmip_HiRAM_SIT_HR
        case "MPI_ESM1_2_XR":
            return .cmip_MPI_ESM1_2_XR
        case "MRI_AGCM3_2_S":
            return .cmip_MRI_AGCM3_2_S
        case "NICAM16_8S":
            return .cmip_NICAM16_8S
        case "ecmwf_ifs":
            return .ecmwf_ifs
        case "ifs04":
            return .ecmwf_ifs04
        case "ifs04_ensemble":
            return .ecmwf_ifs04_ensemble
        case "glofas-consolidated":
            return .glofas_consolidated_v4
        case "glofas-consolidatedv3":
            return .glofas_consolidated_v3
        case "glofas-forecast":
            return .glofas_forecast_v4
        case "glofas-forecastv3":
            return .glofas_forecast_v3
        case "glofas-intermediate":
            return .glofas_intermediate_v4
        case "glofas-intermediatev3":
            return .glofas_intermediate_v3
        case "glofas-seasonalv3":
            return .glofas_seasonal_v3
        case "glofas-seasonal":
            return .glofas_seasonal_v4
        case "arome_france":
            return .meteofrance_arome_france0025
        case "arome_france_hd":
            return .meteofrance_arome_france_hd
        case "arpege_europe":
            return .meteofrance_arpege_europe
        case "arpege_world":
            return .meteofrance_arpege_world025
        case "cams_europe":
            return .cams_europe
        case "cams_global":
            return .cams_global
        case "dem90":
            return .copernicus_dem90
        case "cerra":
            return .copernicus_cerra
        case "era5":
            return .copernicus_era5
        case "era5_land":
            return .copernicus_era5_land
        case "era5_ocean":
            return .copernicus_era5_ocean
        case "gem_global":
            return .cmc_gem_gdps
        case "gem_global_ensemble":
            return .cmc_gem_geps
        case "gem_hrdps_continental":
            return .cmc_gem_hrdps
        case "gem_regional":
            return .cmc_gem_rdps
        case "gfs013":
            return .ncep_gfs013
        case "gfs025":
            return .ncep_gfs025
        case "gfs025_ens":
            return .ncep_gefs025
        case "gfs05_ens":
            return .ncep_gefs05
        case "hrrr_conus":
            return .ncep_hrrr_conus
        case "hrrr_conus_15min":
            return .ncep_hrrr_conus_15min
        case "icon":
            return .dwd_icon
        case "icon-eps":
            return .dwd_icon_eps
        case "icon-d2":
            return .dwd_icon_d2
        case "icon-d2-15min":
            return .dwd_icon_d2_15min
        case "icon-d2-eps":
            return .dwd_icon_d2_eps
        case "icon-eu":
            return .dwd_icon_eu
        case "icon-eu-eps":
            return .dwd_icon_eu_eps
        case "imerg_daily":
            return .nasa_imerg_daily
        case "nordic_pp":
            return .metno_nordic_pp
        default:
            fatalError("Domain \(domain) not mapped")
        }
    }
    
    func rename(variable: String) -> String {
        var result = variable
        result = result.replacingOccurrences(of: "windspeed", with: "wind_speed")
        result = result.replacingOccurrences(of: "winddirection", with: "wind_direction")
        result = result.replacingOccurrences(of: "cloudcover", with: "cloud_cover")
        result = result.replacingOccurrences(of: "weathercode", with: "weather_code")
        result = result.replacingOccurrences(of: "sensible_heatflux", with: "sensible_heat_flux")
        result = result.replacingOccurrences(of: "latent_heatflux", with: "latent_heat_flux")
        result = result.replacingOccurrences(of: "freezinglevel_height", with: "freezing_level_height")
        result = result.replacingOccurrences(of: "soil_moisture_0_1cm", with: "soil_moisture_0_to_1cm")
        result = result.replacingOccurrences(of: "soil_moisture_1_3cm", with: "soil_moisture_1_to_3cm")
        result = result.replacingOccurrences(of: "soil_moisture_3_9cm", with: "soil_moisture_3_to_9cm")
        result = result.replacingOccurrences(of: "soil_moisture_9_27cm", with: "soil_moisture_9_to_27cm")
        result = result.replacingOccurrences(of: "soil_moisture_27_81cm", with: "soil_moisture_27_to_81cm")
        result = result.replacingOccurrences(of: "dewpoint", with: "dew_point")
        result = result.replacingOccurrences(of: "windgusts", with: "wind_gusts")
        result = result.replacingOccurrences(of: "vapor_pressure_deficit", with: "vapour_pressure_deficit")
        result = result.replacingOccurrences(of: "skin_temperature", with: "surface_temperature")
        result = result.replacingOccurrences(of: "surface_air_pressure", with: "surface_pressure")
        result = result.replacingOccurrences(of: "relativehumidity", with: "relative_humidity")
        result = result.replacingOccurrences(of: "eastward_wind", with: "wind_u_component")
        result = result.replacingOccurrences(of: "northward_wind", with: "wind_v_component")
        result = result.replacingOccurrences(of: "atmospheric_relative_vorticity", with: "relative_vorticity")
        return result
    }
    
    func transform(file: String, type: String) -> (directory: String, file: String)? {
        let suffixWithOm = file.split(separator: "_").last!
        let suffix = suffixWithOm.split(separator: ".").first!
        
        if file.starts(with: "HSURF.om") || file.starts(with: "soil_type.om") || file.starts(with: "lat_") {
            return ("static", file)
        }
        
        if file.hasSuffix("linear_bias_seasonal.om") {
            let variable = file.replacingOccurrences(of: "_linear_bias_seasonal.om", with: "")
            return (rename(variable: variable), "linear_bias_seasonal.om")
        }
        
        /*if file.contains("member") {
            // name = river_discharge_member02_89.om
            if #available(macOS 13.0, *) {
                /// member number e.g. "00"
                guard let member = file.split(separator: "_member").last?.split(separator: "_").first else {
                    fatalError("Could not split member file name")
                }
                guard let variable = file.split(separator: "_member").first else {
                    fatalError()
                }
                return (String(variable), "member\(member)_\(type)_\(suffix).om")
            } else {
                fatalError()
            }
        }*/
        
        if Int(suffix) != nil {
            let variable = file.replacingOccurrences(of: "_\(suffixWithOm)", with: "")
            if let last = variable.split(separator: "_").last, let member = Int(last) {
                // member file from CFS like "soil_moisture_100_to_200cm_3_97.om"
                let variable = file.replacingOccurrences(of: "_\(last)_\(suffixWithOm)", with: "")
                return ("\(rename(variable: variable))_member\(member.zeroPadded(len: 2))", "\(type)_\(suffix).om")
            }
            return (rename(variable: variable), "\(type)_\(suffix).om")
        }
        
        if file == "init.txt" || file == "HSURF.nc" {
            return nil
        }
        
        fatalError("No match for \(file)")
    }
}
