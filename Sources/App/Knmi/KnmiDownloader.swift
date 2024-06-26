import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct KnmiDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download KNMI models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try KnmiDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? 1
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        let handles = try await download(application: context.application, domain: domain, run: run)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            //try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    
    /**

     */
    func download(application: Application, domain: KnmiDomain, run: Timestamp) async throws -> [GenericVariableHandle] {
        /*guard let apikey = Environment.get("KNMI_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'KNMI_API_KEY'")
        }*/
        let logger = application.logger
        let deadLineHours = Double(2)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))

        let url = "https://knmi-kdp-datasets-eu-west-1.s3.eu-west-1.amazonaws.com/harmonie_arome_cy43_p3/1.0/HARM43_V1_P3_2024062517.tar?response-content-disposition=attachment%3B%20filename%3D%22HARM43_V1_P3_2024062517.tar%22&x-user=smoke_test_developer_id&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAZWFCFU66KK5PR5F5%2F20240625%2Feu-west-1%2Fs3%2Faws4_request&X-Amz-Date=20240625T202539Z&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEBsaCWV1LXdlc3QtMSJIMEYCIQDXXro6DnjRaivFGVTzVsquvcOHF4kVrnd83nf%2Feo3NzAIhANead1YAc0bUzyxMAcgBXdAT7eVVluxaL4Z%2B1vEhU8TeKqQDCMP%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEQBBoMNjY2MDYwMDQwMTI0IgytL5AhX5%2BdmKFgn7Mq%2BAJ5H05vavWt2j9DSXNuAgBjmC8saqgfL5Ghq5GnlLod%2BO3opSs9xqSaZXek%2B%2BeY7m2FhyIPjaQUsMKDNM%2BdsJQdf9ILUlFN6xmzRbf%2F6Msh1Sl2nTe1iYD5YTkpEyby1sKpcn7tO4bDMQCnhi8I%2FvoklJ5egkUqEWUUpBKuwhHrPZ6n0dmy%2FBONyTqJJ6gb6WAAkLbMahxgD%2Btl8qOicu8Pwc8G6OxF7rvgamPiPBRU6k9cxqaizokr99YHWBUR9a%2FY0Bac%2BrL3TbxO4MsNCi76B1Iaz3oVEiEBl038fSWB6cPh7gWFGZbSuDdICDJo3v8xogbsa1%2BQgQhUrUbjVzJR0bUFMmqN%2BMch4jF62y8ZsmBotyYzT%2BS3GJ%2BZKgjc0lKuBhgl6Wj1pQa7%2B6fht8IuLPIZH9Kp0nn1ZIAq45R38P%2Fndo9G9arWTESrxO1yvUuufwkIj4nI2KtYYKvLIxNmJGjCv8RYEJWj6sxmh9hHsih8gY2cBgMHMNCU7LMGOpwBgK80AUQpHXjT%2B12ioD87yV0BkrCkz932LkiTacoKa7Jb9GsZw84UTxjGIAZ6XA4m7FE4cEmZ%2Fd1YGYkoOcgVGtK%2BkNCjcGdKrJnHJRPA2lY2LQiAjlkS%2FwO8Ur19SqmxIiXqQtjsdkofxFGqU9oae5byKszi9mZB5NLxHViXWm%2Bvq5nIlfRe77IFsCfmVpfRH%2BjUlQvwHkL15Z0G&X-Amz-Signature=fedae2f3361238d441fac97820996c24fc7797786985bc74ab00fb528cdc25e7"
        
        let handles = try await curl.withGribStream(url: url, bzip2Decode: false) { stream in
            
            let previous = GribDeaverager()
            
            // process sequentialy, as precipitation need to be in order for deaveraging
            return try await stream.compactMap { message -> GenericVariableHandle? in
                guard let shortName = message.get(attribute: "shortName"),
                      let stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType"),
                      let levelStr = message.get(attribute: "level"),
                      let typeOfLevel = message.get(attribute: "typeOfLevel"),
                      let parameterName = message.get(attribute: "parameterName"),
                      let parameterUnits = message.get(attribute: "parameterUnits"),
                      let validityTime = message.get(attribute: "validityTime"),
                      let validityDate = message.get(attribute: "validityDate"),
                      let paramId = message.getLong(attribute: "paramId")
                      //let parameterCategory = message.getLong(attribute: "parameterCategory"),
                      //let parameterNumber = message.getLong(attribute: "parameterNumber")
                else {
                    logger.warning("could not get attributes")
                    return nil
                }
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                guard let variable = getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) else {
                    logger.info("Unmapped GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId)")
                    return nil
                }
                
                let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                //message.dumpAttributes()
                try grib2d.load(message: message)
                /*if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }*/
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                // Deaccumulate precipitation
                guard await previous.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                    return nil
                }
                
                logger.info("Compressing and writing data to \(timestamp.format_YYYYMMddHH) \(variable)")
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: stepType == "accum" || stepType == "avg")
            }.collect()
        }
        await curl.printStatistics()
        return handles
    }
    
    func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> MeteoFranceVariableDownloadable? {
        
        switch (parameterName, levelStr) {
        case ("Total cloud cover", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover
        default:
            break
        }
        
        if typeOfLevel == "isobaricInhPa" {
            guard let level = Int(levelStr) else {
                fatalError("Could not parse level str \(levelStr)")
            }
            if level < 10 {
                return nil
            }
            switch shortName {
            case "t":
                return MeteoFrancePressureVariable(variable: .temperature, level: level)
            case "u":
                return MeteoFrancePressureVariable(variable: .wind_u_component, level: level)
            case "v":
                return MeteoFrancePressureVariable(variable: .wind_v_component, level: level)
            case "r":
                return MeteoFrancePressureVariable(variable: .relative_humidity, level: level)
            case "z":
                return MeteoFrancePressureVariable(variable: .geopotential_height, level: level)
            default:
                break
            }
        }
        
        switch (shortName, typeOfLevel, levelStr) {
        case ("t", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.temperature_20m
        case ("t", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.temperature_50m
        case ("t", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.temperature_100m
        case ("t", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.temperature_150m
        case ("t", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.temperature_200m
        case ("u", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.wind_u_component_20m
        case ("u", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.wind_u_component_50m
        case ("100u", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.wind_u_component_100m
        case ("u", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.wind_u_component_150m
        case ("200u", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.wind_u_component_200m
        case ("v", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.wind_v_component_20m
        case ("v", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.wind_v_component_50m
        case ("100v", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.wind_v_component_100m
        case ("v", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.wind_v_component_150m
        case ("200v", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.wind_v_component_200m
            
        default:
            break
        }
        
        switch (shortName, levelStr) {
        case ("2t", "2"):
            return MeteoFranceSurfaceVariable.temperature_2m
        case ("2r", "2"):
            return MeteoFranceSurfaceVariable.relative_humidity_2m
        case ("tp", "0"):
            return MeteoFranceSurfaceVariable.precipitation
        case ("prmsl", "0"):
              return MeteoFranceSurfaceVariable.pressure_msl
        case ("10v", "10"):
              return MeteoFranceSurfaceVariable.wind_v_component_10m
        case ("10u", "10"):
              return MeteoFranceSurfaceVariable.wind_u_component_10m
        case ("clct", "0"):
              return MeteoFranceSurfaceVariable.cloud_cover
        case ("snow_gsp", "0"):
              return MeteoFranceSurfaceVariable.snowfall_water_equivalent
        case ("10fg", "10"):
            return MeteoFranceSurfaceVariable.wind_gusts_10m
        case ("ssrd", "0"):
            return MeteoFranceSurfaceVariable.shortwave_radiation
        case ("lcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_low
        case ("mcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_mid
        case ("hcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_high
        case ("CAPE_INS", "0"):
            return MeteoFranceSurfaceVariable.cape
        case ("tsnowp", "0"):
            return MeteoFranceSurfaceVariable.snowfall_water_equivalent
        default: return nil
        }
    }
}
