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

        let exe = "/usr/local/bin/openmeteo-api"
        print("""
        MAILTO=info@open-meteo.com
        50 2  * * * \(exe) download icon 00 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 8  * * * \(exe) download icon 06 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 14 * * * \(exe) download icon 12 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        50 20 * * * \(exe) download icon 18 > ~/log/icon.log 2>&1 || cat ~/log/icon.log
        10 3  * * * \(exe) download icon-eu 00 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 9  * * * \(exe) download icon-eu 06 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 15 * * * \(exe) download icon-eu 12 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        10 21 * * * \(exe) download icon-eu 18 > ~/log/icon-eu.log 2>&1 || cat ~/log/icon-eu.log
        0  1  * * * \(exe) download icon-d2 00 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  4  * * * \(exe) download icon-d2 03 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  7  * * * \(exe) download icon-d2 06 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  10 * * * \(exe) download icon-d2 09 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  13 * * * \(exe) download icon-d2 12 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  16 * * * \(exe) download icon-d2 15 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  19 * * * \(exe) download icon-d2 18 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        0  22 * * * \(exe) download icon-d2 21 > ~/log/icon-d2.log 2>&1 || cat ~/log/icon-d2.log
        45  7 * * * \(exe) download-ecmwf 00 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0  13 * * * \(exe) download-ecmwf 06 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        45 19 * * * \(exe) download-ecmwf 12 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        0   1 * * * \(exe) download-ecmwf 18 > ~/log/ecmwf.log 2>&1 || cat ~/log/ecmwf.log
        
        0 */8 * * *  \(exe) download-era5 --cdskey 1000000:8ecxxx > ~/log/era5.log 2>&1 || cat ~/log/era5.log
        """)
    }
}
