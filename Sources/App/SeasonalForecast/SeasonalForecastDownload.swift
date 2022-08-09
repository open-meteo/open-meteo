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
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let curl = Curl(logger: logger)
        let timeinterval = TimerangeDt(start: run, nTime: domain.nForecastHours, dtSeconds: domain.dtSeconds)
        let variables = CfsVariable.allCases
        for (step,time) in timeinterval.enumerated() {
            if step <= 4 {
                continue
            }
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.20220808/06/6hrly_grib_01/flxf2022080818.01.2022080806.grb2.idx
            let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/cfs.\(run.format_YYYYMMdd)/\(run.hour.zeroPadded(len: 2))/6hrly_grib_01/flxf\(time.format_YYYYMMddHH).01.\(run.format_YYYYMMddHH).grb2"
            
            for (variable, data2) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                print(variable)
                
                var data = data2
                data.shift180LongitudeAndFlipLatitude()
                for i in data.data.indices {
                    if data.data[i] >= 9999 {
                        data.data[i] = .nan
                    }
                }
                data.data.multiplyAdd(multiply: variable.gribMultiplyAdd.multiply, add: variable.gribMultiplyAdd.add)

                print(data.data[0..<20])
                try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(step).nc")
            }
            
            return
        }
        // loop variables
    }
}


