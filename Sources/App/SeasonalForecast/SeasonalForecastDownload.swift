import Foundation
import Vapor


/**
 
 NCEP CFSv2 https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/00/
 https://rda.ucar.edu/datasets/ds094.0/#metadata/grib2.html?_do=y
 
 requires jpeg2000 support for eccodes, brew needs to rebuild
 brew edit eccodes
 set DENABLE_JPG_LIBJASPER to ON
 brew reinstall eccodes --build-from-source
 */
struct SeasonalForecastDownload: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Flag(name: "skip-existing")
        var skipExisting: Bool
    }

    var help: String {
        "Download seasonal forecasts from Copernicus"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let domain = SeasonalForecastDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        let run = Timestamp.now().with(hour: 0)
        try downloadCFS(logger: logger, domain: domain, run: run)
    }
    
    func downloadCFS(logger: Logger, domain: SeasonalForecastDomain, run: Timestamp) throws {
        // loop timesteps
        let curl = Curl(logger: logger)
        let timeinterval = TimerangeDt(start: run, nTime: domain.nForecastHours, dtSeconds: domain.dtSeconds)
        let variables = Array(CfsVariable.allCases[0..<2])
        for (step,time) in timeinterval.enumerated() {
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/06/6hrly_grib_01/flxf2022080818.01.2022080806.grb2.idx
            let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(time.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
            
            for (variable, data) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                print(variable)
                print(data[0..<10])
            }
            
            
        }
        // loop variables
    }
}


