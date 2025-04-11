import Foundation
import Vapor
import SwiftEccodes
import OmFileFormat

/**
 Modifications / Calculations:
 - deaccumulate precipitation and snow
 - deaverage radiation
 - relative humidity 2m from temperature and dew point
 - sum up snowfall from SNOW_CON + SNOW_GSP
 - correct weather code for temperature, precipitation and snowfall height
 - correct freezinglevel and snow height based on temperature and elevation
 - add snow to rain if temperature > 1.5°
 - set snow to 0 if temperature > 1.5
 - wind speed & direction from U/V levels
 - calculate vertical velocity
 */
struct ItaliaMeteoArpaeDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download ItaliaMeteo Arpae models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try ItaliaMeteoArpaeDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? 4
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try await downloadElevation(application: context.application, domain: domain, run: run)
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    func downloadElevation(application: Application, domain: ItaliaMeteoArpaeDomain, run: Timestamp) async throws {
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm.getFilePath()) {
            return
        }
        try surfaceElevationFileOm.createDirectory()
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 1)
        let runString = run.format_YYYYMMddHH
        
        let grid = domain.grid
        let urlLand = "https://meteohub.mistralportal.it/nwp/ICON-2I_all2km/\(runString)/FR_LAND/icon_2I_\(runString)_surface-0.grib"
        /// fraction 0=sea, 1=land
        let landmask = try await curl.downloadGrib(url: urlLand, bzip2Decode: false)[0].to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
        
        let urlElevation = "https://meteohub.mistralportal.it/nwp/ICON-2I_all2km/\(runString)/HSURF/icon_2I_\(runString)_surface-0.grib"
        var elevation = try await curl.downloadGrib(url: urlElevation, bzip2Decode: false)[0].to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
        
        for i in elevation.array.data.indices {
            if landmask.array.data[i] < 0.5 {
                elevation.array.data[i] = -999
            }
        }
        
        try elevation.array.data.writeOmFile2D(file: surfaceElevationFileOm.getFilePath(), grid: domain.grid, createNetCdf: false)
    }
    
    func download(application: Application, domain: ItaliaMeteoArpaeDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = Double(6)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        struct VariableLevel: Hashable {
            let variable: ItaliaMeteoArpaeVariablesDownload
            let level: String
        }
        
        /// Domain elevation field. Used to calculate sea level pressure from surface level pressure in ICON EPS and ICON EU EPS
        let domainElevation = {
            guard let elevation = try? domain.getStaticFile(type: .elevation)?.read() else {
                fatalError("cannot read elevation for domain \(domain)")
            }
            return elevation
        }()
        
        let grid = domain.grid
        let writer = OmFileWriterAndHandles(domain: domain, nMembers: domain.ensembleMembers)
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        let variableLevel: [VariableLevel] = ItaliaMeteoArpaeVariablesDownload.allCases.flatMap({ variable in
            variable.levels.map { level in
                return VariableLevel(variable: variable, level: level)
            }
        })
        let runString = run.format_YYYYMMddHH
        
        let inMemory = VariablePerMemberStorage<VariableLevel>()
        for v in variableLevel {
            if v.variable == .T_SO || v.variable == .W_SO {
                continue
            }
            let url = "https://meteohub.mistralportal.it/nwp/ICON-2I_all2km/\(runString)/\(v.variable)/icon_2I_\(runString)_\(v.level).grib"
            let deaverager = GribDeaverager()
            for message in try await curl.downloadGrib(url: url, bzip2Decode: false) {
                let attributes = try message.getAttributes()
                let time = attributes.timestamp
                let member = 0
                var array2d = try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
                switch v.variable {
                case .T, .TD_2M, .T_2M, .T_SO:
                    array2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                case .PMSL:
                    array2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
                case .FI:
                    // convert geopotential to height (WMO defined gravity constant)
                    array2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                default:
                    break
                }
                // Deaccumulate precipitation
                guard await deaverager.deaccumulateIfRequired(variable: v, member: member, stepType: attributes.stepType.rawValue, stepRange:  attributes.stepRange, grib2d: &array2d) else {
                    continue
                }
                if v.variable.keepInMemory {
                    await inMemory.set(variable: v, timestamp: attributes.timestamp, member: member, data: array2d.array)
                }
                
                /// Calculate 10m wind
                if v.variable == .V_10M {
                    guard let uWind = await inMemory.getAndForget(.init(variable: .init(variable: .U_10M, level: v.level), timestamp: time, member: member)) else {
                        fatalError("U_10M must be loaded before \(v.variable)")
                    }
                    let vWind = array2d.array
                    let speed = zip(uWind.data, vWind.data).map(Meteorology.windspeed)
                    let direction = Meteorology.windirectionFast(u: uWind.data, v: vWind.data)
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.wind_speed_10m, time: time, member: member, data: speed)
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.wind_direction_10m, time: time, member: member, data: direction)
                }
                
                /// Calculate pressure level wind
                if v.variable == .V {
                    guard let uWind = await inMemory.getAndForget(.init(variable: .init(variable: .U, level: v.level), timestamp: time, member: member)) else {
                        fatalError("U wind must be loaded before \(v.variable)")
                    }
                    let vWind = array2d.array
                    let speed = zip(uWind.data, vWind.data).map(Meteorology.windspeed)
                    let direction = Meteorology.windirectionFast(u: uWind.data, v: vWind.data)
                    try await writer.append(variable: ItaliaMeteoArpaePressureVariable(variable: .wind_speed, level: Int(attributes.levelStr)!), time: time, member: member, data: speed)
                    try await writer.append(variable: ItaliaMeteoArpaePressureVariable(variable: .wind_direction, level: Int(attributes.levelStr)!), time: time, member: member, data: direction)
                }
                
                /// Lower freezing level height below grid-cell elevation to adjust data to mixed terrain
                /// Use temperature to estimate freezing level height below ground. This is consistent with GFS
                /// https://github.com/open-meteo/open-meteo/issues/518#issuecomment-1827381843
                /// Note: snowfall height is NaN if snowfall height is at ground level
                if v.variable == .HZEROCL || v.variable == .SNOWLMT {
                    guard let t2m = await inMemory.get(.init(variable: .init(variable: .T_2M, level: "heightAboveGround-2"), timestamp: time, member: member)) else {
                        fatalError("T2M must be loaded before \(v.variable)")
                    }
                    for i in array2d.array.data.indices {
                        let freezingLevelHeight = array2d.array.data[i].isNaN ? max(0, domainElevation[i]) : array2d.array.data[i]
                        let temperature_2m = t2m.data[i]
                        let newHeight = freezingLevelHeight - abs(-1 * temperature_2m) * 0.7 * 100
                        if newHeight <= domainElevation[i] {
                            array2d.array.data[i] = newHeight
                        }
                    }
                }
                
                // ICON weather codes show rain although precipitation is 0
                // Similar for snow at +2°C or more
                if v.variable == .WW {
                   guard let t2m = await inMemory.get(.init(variable: .init(variable: .T_2M, level: "heightAboveGround-2"), timestamp: time, member: member)),
                         let snowfallHeight = await inMemory.get(.init(variable: .init(variable: .SNOWLMT, level: "isothermZero-0"), timestamp: time, member: member)) else {
                       fatalError("T2M, TOT_PREC and SNOWLMT must be loaded before \(v.variable)")
                    }
                    /// precipitation hour 0 is not available
                    let precip = await inMemory.get(.init(variable: .init(variable: .TOT_PREC, level: "surface-0"), timestamp: time, member: member))
                    for i in array2d.array.data.indices {
                        guard array2d.array.data[i].isFinite, let weathercode = WeatherCode(rawValue: Int(array2d.array.data[i])) else {
                            continue
                        }
                        array2d.array.data[i] = Float(weathercode.correctDwdIconWeatherCode(
                            temperature_2m: t2m.data[i],
                            precipitation: precip?.data[i] ?? .nan,
                            snowfallHeightAboveGrid: t2m.data[i] > 0 && snowfallHeight.data[i] > max(0, domainElevation[i]) + 50
                        ).rawValue)
                    }
                }
                
                /// Add snow to liquid rain if temperature is > 1.5°C or snowfall height is higher than 50 metre above ground
                /// Set snow to 0 if temperature is > 1.5°C or snowfall height is higher than 50 metre above ground
                if v.variable == .SNOW_GSP {
                    guard let t2m = await inMemory.get(.init(variable: .init(variable: .T_2M, level: "heightAboveGround-2"), timestamp: time, member: member)),
                          let snowfallHeight = await inMemory.get(.init(variable: .init(variable: .SNOWLMT, level: "isothermZero-0"), timestamp: time, member: member)),
                          let snowCon = await inMemory.get(.init(variable: .init(variable: .SNOW_CON, level: "surface-0"), timestamp: time, member: member)),
                          let rainCon = await inMemory.get(.init(variable: .init(variable: .RAIN_CON, level: "surface-0"), timestamp: time, member: member)),
                          let rainGsp = await inMemory.get(.init(variable: .init(variable: .RAIN_GSP, level: "surface-0"), timestamp: time, member: member))
                    else {
                        fatalError("T2M, SNOWLMT, SNOW_CON, RAIN_CON and RAIN_GSP must be loaded before \(v.variable)")
                     }
                    let snowGsp = array2d.array
                    var snow = snowGsp.data
                    var rain = snowGsp.data
                    var showers = snowGsp.data
                    for i in t2m.data.indices {
                        let aboveFreezing = t2m.data[i] > IconDomains.tMelt || (t2m.data[i] > 0 && snowfallHeight.data[i] > max(0, domainElevation[i]) + 50)
                        rain[i] = rainGsp.data[i] + (aboveFreezing ? snowGsp.data[i] : 0)
                        showers[i] = rainCon.data[i] + (aboveFreezing ? snowCon.data[i] : 0)
                        snow[i] = aboveFreezing ? 0 : (snowGsp.data[i] + snowCon.data[i])
                    }
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.rain, time: time, member: member, data: rain)
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.showers, time: time, member: member, data: showers)
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.snowfall_water_equivalent, time: time, member: member, data: snow)
                }
                
                /// Calculate relative humidity from dew point
                if v.variable == .TD_2M {
                    guard let t2m = await inMemory.get(.init(variable: .init(variable: .T_2M, level: "heightAboveGround-2"), timestamp: time, member: member)) else {
                        fatalError("T2M must be loaded before \(v.variable)")
                    }
                    let rh = zip(t2m.data, array2d.array.data).map( Meteorology.relativeHumidity)
                    try await writer.append(variable: ItaliaMeteoArpaeSurfaceVariable.relative_humidity_2m, time: time, member: member, data: rh)
                }
                
                /// Convert vertical pressure velocity to geometric velocity
                if v.variable == .OMEGA {
                    guard let t = await inMemory.get(.init(variable: .init(variable: .T, level: v.level), timestamp: time, member: member)) else {
                        fatalError("T must be loaded before \(v.variable)")
                    }
                    let level = Int(attributes.levelStr)!
                    let vv = Meteorology.verticalVelocityPressureToGeometric(omega: array2d.array.data, temperature: t.data, pressureLevel: Float(level))
                    try await writer.append(variable: ItaliaMeteoArpaePressureVariable.init(variable: .vertical_velocity, level: level), time: time, member: member, data: vv)
                }
                
                if let variable = v.variable.getGenericVariable(attributes: attributes) {
                    try await writer.append(variable: variable, time: time, member: member, data: array2d.array.data)
                }
            }
        }
        return await writer.handles.handles
    }
}
