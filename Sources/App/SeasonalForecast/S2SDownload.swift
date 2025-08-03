import Foundation
import Vapor
import OmFileFormat
@preconcurrency import SwiftEccodes


/**
 
 */
struct S2SDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "only-variables")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API key like: f412e2d2-4123-456...")
        var cdskey: String?
    }

    var help: String {
        "Download S2S forecasts from Copernicus"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try S2S6HourlyDomain.load(rawValue: signature.domain)
        disableIdleSleep()
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD)! //?? domain.lastRun
        
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        
        let _ = try await downloadEcds(application: context.application, domain: domain, run: run, cdskey: cdskey, concurrent: 1)

       

        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(logger: context.application.logger, bucket: uploadS3Bucket, variables: CfsVariable.allCases)
        }
    }
    
    
    struct EcdsQuery: Encodable {
        let origin: String // ecmwf
        let forecast_type: String // control_forecast or perturbed_forecast
        let level_type: String // single_level
        //let height_level: String?
        let year: String
        let month: String
        let day: String
        let leadtime_hour: [String]
        let variable: [String]
        let time: String // reference time: 00:00
        let data_format = "grib"
    }
    /**
     6-hourly
     dataset = "s2s-forecasts"
     request = {
         "origin": "ecmwf",
         "forecast_type": "control_forecast",
         "level_type": "single_level",
         "variable": [
             "10m_u_component_of_wind",
             "10m_v_component_of_wind",
             "maximum_2m_temperature_last_6_hours",
             "minimum_2m_temperature_last_6_hours",
             "total_precipitation"
         ],
         "year": "2025",
         "month": "07",
         "day": "28",
         "leadtime_hour": [
             "6",
             "12",
             "18"
         ],
         "time": "00:00",
         "data_format": "grib"
     }

        0z archived values:
     dataset = "s2s-forecasts"
     request = {
         "origin": "ecmwf",
         "forecast_type": "control_forecast",
         "level_type": "single_level",
         "variable": [
             "convective_precipitation",
             "mean_sea_level_pressure",
             "snow_fall_water_equivalent",
             "surface_runoff",
             "surface_solar_radiation_downwards",
             "total_precipitation",
             "water_runoff_and_drainage"
         ],
         "year": "2025",
         "month": "07",
         "day": "28",
         "leadtime_hour": [
             "0",
             "24",
             "48"
         ],
         "time": "00:00",
         "data_format": "grib"
     }
     
     
     daily:
     dataset = "s2s-forecasts"
     request = {
         "origin": "ecmwf",
         "forecast_type": "control_forecast",
         "level_type": "single_level",
         "variable": [
             "2m_dewpoint_temperature",
             "2m_temperature",
             "convective_available_potential_energy",
             "sea_ice_area_fraction",
             "sea_surface_temperature",
             "skin_temperature",
             "snow_albedo",
             "snow_density",
             "snow_depth_water_equivalent",
             "soil_moisture_top_20_cm",
             "soil_moisture_top_100_cm",
             "soil_temperature_top_100_cm",
             "soil_temperature_top_20_cm",
             "total_cloud_cover",
             "total_column_water"
         ],
         "year": "2025",
         "month": "07",
         "day": "29",
         "leadtime_hour": [
             "0_24",
             "24_48",
             "48_72"
         ],
         "time": "00:00",
         "data_format": "grib"
     }
     
     
     */
    
    func downloadEcds(application: Application, domain: S2S6HourlyDomain, run: Timestamp, cdskey: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let query = EcdsQuery(origin: "ecmwf", forecast_type: "control_forecast", level_type: "single_level", year: "2025", month: "07", day: "28", leadtime_hour: stride(from: 0, through: 12, by: 6).map(String.init), variable: [
            "10m_u_component_of_wind",
            "10m_v_component_of_wind",
            "maximum_2m_temperature_last_6_hours",
            "minimum_2m_temperature_last_6_hours",
            "total_precipitation"
        ], time: "00:00")
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let h = try await curl.withCdsApi(dataset: "s2s-forecast", query: query, apikey: cdskey, server: "https://ecds-preprod.ecmwf.int/api") { stream in
            let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil)
            
            try await stream.foreachConcurrent(nConcurrent: concurrent) { message in
                let attributes = try GribAttributes(message: message)
                let timestamp = attributes.timestamp
                guard let variable = S2SVariable6Hourly.fromGrib(attributes: attributes) else {
                    fatalError("Could not find \(attributes) in grib")
                }
                logger.info("Converting variable \(variable) \(timestamp.format_YYYYMMddHH) \(message.get(attribute: "name")!)")
                var grib2d = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: true)
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                try await writer.write(time: timestamp, member: attributes.perturbationNumber ?? 0, variable: variable, data: grib2d.array.data)
            }
            return try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: nil)
        }
        return h
    }
}
