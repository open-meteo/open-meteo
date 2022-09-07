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
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        36 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon-eu > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download icon-d2 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --upper-level > ~/log/icon_upper-level.log 2>&1 || cat ~/log/icon_upper-level.log
        36 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon-eu --upper-level > ~/log/icon-eu_upper-level.log 2>&1 || cat ~/log/icon-eu_upper-level.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download --upper-level icon-d2 > ~/log/icon-d2_upper-level.log 2>&1 || cat ~/log/icon-d2_upper-level.log
        
        37 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon --model-level > ~/log/icon_model-level.log 2>&1 || cat ~/log/icon_model-level.log
        36 2,8,14,20  * * * /usr/local/bin/openmeteo-api download icon-eu --model-level > ~/log/icon-eu_model-level.log 2>&1 || cat ~/log/icon-eu_model-level.log
        44 0,3,6,9,12,15,18,21 * * * /usr/local/bin/openmeteo-api download --model-level icon-d2 > ~/log/icon-d2_model-level.log 2>&1 || cat ~/log/icon-d2_model-level.log
        
        45  7,19 * * * /usr/local/bin/openmeteo-api download-ecmwf > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0  1,13 * * * /usr/local/bin/openmeteo-api download-ecmwf > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        
        40  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave gwam > ~/log/iconwave_gwam.log 2>&1 || cat ~/log/iconwave_gwam.log
        30  3,15 * * * /usr/local/bin/openmeteo-api download-iconwave ewam > ~/log/iconwave_ewam.log 2>&1 || cat ~/log/iconwave_ewam.log
        
        0 */8 * * *  /usr/local/bin/openmeteo-api download-era5 --cdskey 1000000:8ecxxx > ~/log/era5.log 2>&1 || cat ~/log/era5.log
        
        0 8,20 * * * /usr/local/bin/openmeteo-api download-cams cams_global --ftpuser XXXXX --ftppassword XXXXXX > ~/log/cams_global.log 2>&1 || cat ~/log/cams_global.log
        30 9 * * * /usr/local/bin/openmeteo-api download-cams cams_europe --cdskey 101234:XXXXXX-XXXXXX-XXXXX-XXXXX > ~/log/cams_europe.log 2>&1 || cat ~/log/cams_europe.log
        
        20 5,11,17,23 * * * /usr/local/bin/openmeteo-api download-seasonal-forecast ncep > ~/log/seasonal_ncep.log 2>&1 || cat ~/log/seasonal_ncep.log
        
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 > ~/log/gfs025.log 2>&1 || cat ~/log/gfs025.log
        55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus > ~/log/hrrr_conus.log 2>&1 || cat ~/log/hrrr_conus.log
        
        40 3,9,15,21 * * * /usr/local/bin/openmeteo-api download-gfs gfs025 --upper-level > ~/log/gfs025_upper-level.log 2>&1 || cat ~/log/gfs025_upper-level.log
        55 * * * * /usr/local/bin/openmeteo-api download-gfs hrrr_conus --upper-level > ~/log/hrrr_conus_upper-level.log 2>&1 || cat ~/log/hrrr_conus_upper-level.log
        """)
    }
}
