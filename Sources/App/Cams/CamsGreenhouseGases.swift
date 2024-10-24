/**
 dataset = "cams-global-greenhouse-gas-forecasts"
 request = {
     "variable": [
         "carbon_dioxide",
         "carbon_monoxide",
         "methane"
     ],
     "model_level": ["137"],
     "date": ["2024-10-22/2024-10-22"],
     "leadtime_hour": [
         "0",
         "3",
        ...
         "117",
         "120"
     ],
     "data_format": "grib"
 */
import Vapor

extension DownloadCamsCommand {
    

    
    func downloadCamsGlobalGreenhouseGases(application: Application, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String) async throws -> [GenericVariableHandle] {
        
        let date = run.iso8601_YYYY_MM_dd
        let forecastHours = domain.forecastHours
        /*let query = CamsEuropeQuery(
            date: "\(date)/\(date)",
            type: nil,
            data_format: "netcdf",
            variable: variables.compactMap { $0.getCamsEuMeta()?.apiName },
            level: ["0"],
            time: "\(run.hour.zeroPadded(len: 2)):00",
            leadtime_hour: S (0..<forecastHours).map(String.init),
            year: nil,
            month: nil,
            model_level: nil
        )*/
        
        fatalError()
    }
}
