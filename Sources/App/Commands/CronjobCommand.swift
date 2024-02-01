import Foundation
import Vapor


struct CronjobCommand: Command {
    struct Signature: CommandSignature {
    }

    var help: String {
        "Emits the cronjob definition"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        print("""
        MAILTO=info@open-meteo.com
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group surface > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        36 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group surface > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group surface > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group pressureLevelGt500 > ~/log/icon_upper-levelgt500.log 2>&1 || cat ~/log/icon_upper-levelgt500.log
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group pressureLevelLtE500 > ~/log/icon_upper-levellte500.log 2>&1 || cat ~/log/icon_upper-levellte500.log
        36 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group pressureLevel > ~/log/icon-eu_upper-level.log 2>&1 || cat ~/log/icon-eu_upper-level.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group pressureLevel > ~/log/icon-d2_upper-level.log 2>&1 || cat ~/log/icon-d2_upper-level.log
        
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --group modelLevel > ~/log/icon_model-level.log 2>&1 || cat ~/log/icon_model-level.log
        36 2,5,8,11,14,17,20,23  * * * /usr/local/bin/openmeteo-api download icon-eu --group modelLevel > ~/log/icon-eu_model-level.log 2>&1 || cat ~/log/icon-eu_model-level.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 --group modelLevel > ~/log/icon-d2_model-level.log 2>&1 || cat ~/log/icon-d2_model-level.log
        
        45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0   1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        
        40  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave gwam > ~/log/iconwave_gwam.log 2>&1 || cat ~/log/iconwave_gwam.log
        30  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave ewam > ~/log/iconwave_ewam.log 2>&1 || cat ~/log/iconwave_ewam.log
        
        0 */8 * * *  /usr/local/bin/openmeteo-api download-era5 --cdskey 1000000:8ecxxx > ~/log/era5.log 2>&1 || cat ~/log/era5.log
        
        0 8,20 * * * /usr/local/bin/openmeteo-api download-cams cams_global --ftpuser XXXXX --ftppassword XXXXXX > ~/log/cams_global.log 2>&1 || cat ~/log/cams_global.log
        30 9 * * * /usr/local/bin/openmeteo-api download-cams cams_europe --cdskey 101234:XXXXXX-XXXXXX-XXXXX-XXXXX > ~/log/cams_europe.log 2>&1 || cat ~/log/cams_europe.log
        
        20 5,11,17,23 * * * /usr/local/bin/openmeteo-api download-seasonal-forecast ncep > ~/log/seasonal_ncep.log 2>&1 || cat ~/log/seasonal_ncep.log
        
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 > ~/log/gfs025.log 2>&1 || cat ~/log/gfs025.log
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs013 > ~/log/gfs013.log 2>&1 || cat ~/log/gfs013.log
        55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus > ~/log/hrrr_conus.log 2>&1 || cat ~/log/hrrr_conus.log
        55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus_15min > ~/log/hrrr_conus_15min.log 2>&1 || cat ~/log/hrrr_conus_15min.log
        
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 --upper-level > ~/log/gfs025_upper-level.log 2>&1 || cat ~/log/gfs025_upper-level.log
        55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus --upper-level > ~/log/hrrr_conus_upper-level.log 2>&1 || cat ~/log/hrrr_conus_upper-level.log
        
        0 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-meteofrance arpege_world > ~/log/arpege_world.log 2>&1 || cat ~/log/arpege_world.log
        0 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-meteofrance arpege_world --upper-level > ~/log/arpege_world_upper-level.log 2>&1 || cat ~/log/arpege_world_upper-level.log
        
        0 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-meteofrance arpege_europe > ~/log/arpege_europe.log 2>&1 || cat ~/log/arpege_europe.log
        0 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-meteofrance arpege_europe --upper-level > ~/log/arpege_europe_upper-level.log 2>&1 || cat ~/log/arpege_europe_upper-level.log
        
        0 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-meteofrance arome_france > ~/log/arome_france.log 2>&1 || cat ~/log/arome_france.log
        0 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-meteofrance arome_france --upper-level > ~/log/arome_france_upper-level.log 2>&1 || cat ~/log/arome_france_upper-level.log
        
        0 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-meteofrance arome_france_hd > ~/log/arome_france_hd.log 2>&1 || cat ~/log/arome_france_hd.log

        27 * * * * /usr/local/bin/openmeteo-api download-metno nordic_pp > ~/log/nordic_pp.log 2>&1 || cat ~/log/nordic_pp.log
        
        7 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gem gem_hrdps_continental > ~/log/gem_hrdps_continental.log 2>&1 || cat ~/log/gem_hrdps_continental.log
        47 2,8,14,20 * * * /usr/local/bin/openmeteo-api download-gem gem_regional > ~/log/gem_regional.log 2>&1 || cat ~/log/gem_regional.log
        39 3,15 * * * /usr/local/bin/openmeteo-api download-gem gem_global > ~/log/gem_global.log 2>&1 || cat ~/log/gem_global.log
        
        
        40 4,16 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_2i --concurrent 4 > ~/log/cosmo_2i.log 2>&1 || cat ~/log/cosmo_2i.log
        45 3,15 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_5m --concurrent 4 > ~/log/cosmo_5m.log 2>&1 || cat ~/log/cosmo_5m.log
        50 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download-arpae cosmo_2i_ruc --concurrent 4 > ~/log/cosmo_2i_ruc.log 2>&1 || cat ~/log/cosmo_2i_ruc.log
        
        
        # Ensemble models
        37 2,14  * * * /usr/local/bin/openmeteo-api download icon-eps > ~/log/icon-eps.log 2>&1 || cat ~/log/icon-eps.log
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon-eu-eps > ~/log/icon-eu-eps.log 2>&1 || cat ~/log/icon-eu-eps.log
        30 1,4,7,10,13,16,19,22  * * * /usr/local/bin/openmeteo-api download icon-d2-eps > ~/log/icon-d2-eps.log 2>&1 || cat ~/log/icon-d2-eps.log
        
        45 7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs04_ensemble > ~/log/ifs04_ensemble.log 2>&1 || cat ~/log/ifs04_ensemble.log
        0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf --domain ifs04_ensemble > ~/log/ifs04_ensemble.log 2>&1 || cat ~/log/ifs04_ensemble.log
        
        45 4,16 * * * /usr/local/bin/openmeteo-api download-gem gem_global_ensemble > ~/log/gem_global_ensemble.log 2>&1 || cat ~/log/gem_global_ensemble.log
        #45 4,16 * * * /usr/local/bin/openmeteo-api download-gem gem_global_ensemble --upper-level > ~/log/gem_global_ensemble.log 2>&1 || cat ~/log/gem_global_ensemble.log
        
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025_ens > ~/log/gfs025_ens.log 2>&1 || cat ~/log/gfs025_ens.log
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens > ~/log/gfs05_ens.log 2>&1 || cat ~/log/gfs05_ens.log
        #40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --upper-level > ~/log/gfs05_ens_upper-level.log 2>&1 || cat ~/log/gfs05_ens_upper-level.log
        55 23 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --second-flush --run 0 > ~/log/gfs05_ens-second-flush.log 2>&1 || cat ~/log/gfs05_ens-second-flush.log
        #55 23 * * * /usr/local/bin/openmeteo-api download-gfs gfs05_ens --second-flush --run 0 --upper-level > ~/log/gfs05_ens-second-flush_upper-level.log 2>&1 || cat ~/log/gfs05_ens-second-flush_upper-level.log
        """)
    }
}
