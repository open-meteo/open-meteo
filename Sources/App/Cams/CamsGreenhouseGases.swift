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
import OmFileFormat

extension DownloadCamsCommand {
    /**
     Download CAMS Global Greenhouse Gas forecast from ADS
     */
    func downloadCamsGlobalGreenhouseGases(application: Application, domain: CamsDomain, run: Timestamp, skipFilesIfExisting: Bool, variables: [CamsVariable], cdskey: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        let date = run.iso8601_YYYY_MM_dd
        let forecastHours = domain.forecastHours
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 24)
        let query = CamsEuropeQuery(
            model: nil,
            date: "\(date)/\(date)",
            type: nil,
            data_format: "grib",
            variable: variables.compactMap { $0.getCamsGlobalGreenhouseGasesMeta()?.apiname },
            level: nil,
            time: nil,
            leadtime_hour: stride(from: 0, through: forecastHours - 1, by: domain.dtHours).map(String.init),
            year: nil,
            month: nil,
            model_level: [137]
        )

        let writer = OmFileSplitter.makeSpatialWriter(domain: domain)

        return try await curl.withCdsApi(
            dataset: "cams-global-greenhouse-gas-forecasts",
            query: query,
            apikey: cdskey,
            server: "https://ads.atmosphere.copernicus.eu/api") { messages in
                return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    let attributes = try GribAttributes(message: message)
                    let timestamp = attributes.timestamp
                    let shortName = attributes.shortName
                    guard let variable = CamsVariable.allCases.first(where: { $0.getCamsGlobalGreenhouseGasesMeta()?.gribShortName == shortName }) else {
                        fatalError("Could not find variable for \(attributes)")
                    }

                    logger.info("Converting variable \(variable) \(timestamp.format_YYYYMMddHH) \(message.get(attribute: "name")!)")

                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    try grib2d.load(message: message)
                    if let scaling = variable.getCamsGlobalGreenhouseGasesMeta()?.scalefactor {
                        grib2d.array.data.multiplyAdd(multiply: scaling, add: 0)
                    }
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn)
                }.collect().compactMap({ $0 })
        }
    }
}
