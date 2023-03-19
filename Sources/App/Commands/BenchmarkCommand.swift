import Foundation
import Vapor
import CHelper
import SwiftPFor2D


struct BenchmarkCommand: Command {
    struct Signature: CommandSignature {}
    
    var help: String { "Run benchmark" }
    
    /// `swift run -c release Run benchmark`
    func run(using context: CommandContext, signature: Signature) throws {
        
        let file = try OmFileReader(file: "/Volumes/2TB_1GBs/data/master-MRI_AGCM3_2_S/temperature_2m_max_0.om")
        var array = [Float](repeating: .nan, count: 365*100)
        let chunkBuffer = OmFileReader<MmapFile>.getBuffer(minBytes: P4NDEC256_BOUND(n: file.chunk0*file.chunk1, bytesPerElement: file.compression.bytesPerElement)).baseAddress!
        try array.withUnsafeMutableBufferPointer({ ptr in
            try file.read(into: ptr.baseAddress!,  arrayDim1Range: 0..<ptr.count, arrayDim1Length: ptr.count, chunkBuffer: chunkBuffer, dim0Slow: 100..<101, dim1: 0..<ptr.count)
            let start = DispatchTime.now()
            for _ in 1..<2000 {
                try file.read(into: ptr.baseAddress!,  arrayDim1Range: 0..<ptr.count, arrayDim1Length: ptr.count, chunkBuffer: chunkBuffer, dim0Slow: 100..<101, dim1: 0..<ptr.count)
            }
            context.console.info("Time \(start.timeElapsedPretty())")
        })
        
        /*try array.withUnsafeMutableBufferPointer({ ptr in
            try file.read3(into: ptr.baseAddress!,  arrayDim1Range: 0..<ptr.count, arrayDim1Length: ptr.count, chunkBuffer: chunkBuffer, dim0Slow: 100..<101, dim1: 0..<ptr.count)
            let start = DispatchTime.now()
            for _ in 1..<2000 {
                try file.read3(into: ptr.baseAddress!,  arrayDim1Range: 0..<ptr.count, arrayDim1Length: ptr.count, chunkBuffer: chunkBuffer, dim0Slow: 100..<101, dim1: 0..<ptr.count)
            }
            context.console.info("Time \(start.timeElapsedPretty())")
        })*/
                
        //for _ in 1..<60000000 {
            /*let currentTime = Timestamp(Int(Date().timeIntervalSince1970))
            
            let time = ForecastapiController.forecastTimeRange(currentTime: currentTime, utcOffsetSeconds: 0, pastDays: 0, forecastDays: 7)
            let reader = try IconMixer(lat: -47, lon: 5, asl: nil, time: time)
            let hourly = WeatherVariable.allCases
            try reader.prefetchData(variables: hourly)
            let params = ForecastapiQuery(latitude: 47, longitude: 6, hourly: [], daily: [], current_weather: false, elevation: nil, timezone: nil, temperature_unit: nil, windspeed_unit: nil, precipitation_unit: nil, timeformat: nil, past_days: nil, use_om_file: nil)
            for variable in hourly {
                _ = try reader.getConverted(variable: variable, params: params)
            }*/
        //}
        
        
        /*let x = (1..<600_000).map{Float($0)}
        let y = (1..<600_000).map{Float($0)}
        
        start = DispatchTime.now()
        let res = zip(x,y).map(atan2)
        context.console.info("Time atan2 \(start.timeElapsedPretty()), res \(res[0])")

        start = DispatchTime.now()
        let res3 = Meteorology.windirectionFast(u: x, v: y)
        context.console.info("Time windirectionFast \(start.timeElapsedPretty()), res \(res3[0])")*/
    }
}
