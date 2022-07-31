import Foundation
import Vapor


struct CronjobCommand: Command {
    struct Signature: CommandSignature {
    }

    var help: String {
        "Emits the cronjob definition"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        // TODO this file needs larger updates

        print("""
        MAILTO=info@open-meteo.com
        50 2  * * * /usr/local/bin/openmeteo-api download icon 00 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 8  * * * /usr/local/bin/openmeteo-api download icon 06 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 14 * * * /usr/local/bin/openmeteo-api download icon 12 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 20 * * * /usr/local/bin/openmeteo-api download icon 18 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        10 3  * * * /usr/local/bin/openmeteo-api download icon-eu 00 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 9  * * * /usr/local/bin/openmeteo-api download icon-eu 06 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 15 * * * /usr/local/bin/openmeteo-api download icon-eu 12 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 21 * * * /usr/local/bin/openmeteo-api download icon-eu 18 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        0  1  * * * /usr/local/bin/openmeteo-api download icon-d2 00 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  4  * * * /usr/local/bin/openmeteo-api download icon-d2 03 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  7  * * * /usr/local/bin/openmeteo-api download icon-d2 06 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  10 * * * /usr/local/bin/openmeteo-api download icon-d2 09 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  13 * * * /usr/local/bin/openmeteo-api download icon-d2 12 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  16 * * * /usr/local/bin/openmeteo-api download icon-d2 15 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  19 * * * /usr/local/bin/openmeteo-api download icon-d2 18 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  22 * * * /usr/local/bin/openmeteo-api download icon-d2 21 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        45  7 * * * /usr/local/bin/openmeteo-api download-ecmwf 00 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0  13 * * * /usr/local/bin/openmeteo-api download-ecmwf 06 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        45 19 * * * /usr/local/bin/openmeteo-api download-ecmwf 12 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0   1 * * * /usr/local/bin/openmeteo-api download-ecmwf 18 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        
        40  3 * * * /usr/local/bin/openmeteo-api download-iconwave gwam 00 > ~/log/iconwave_gwam.log 2>&1 || cat ~/log/iconwave_gwam.log
        40 15 * * * /usr/local/bin/openmeteo-api download-iconwave gwam 12 > ~/log/iconwave_gwam.log 2>&1 || cat ~/log/iconwave_gwam.log
        30  3 * * * /usr/local/bin/openmeteo-api download-iconwave ewam 00 > ~/log/iconwave_ewam.log 2>&1 || cat ~/log/iconwave_ewam.log
        30 15 * * * /usr/local/bin/openmeteo-api download-iconwave ewam 12 > ~/log/iconwave_ewam.log 2>&1 || cat ~/log/iconwave_ewam.log
        
        0 */8 * * *  /usr/local/bin/openmeteo-api download-era5 --cdskey 1000000:8ecxxx > ~/log/era5.log 2>&1 || cat ~/log/era5.log
        """)
    }
}
