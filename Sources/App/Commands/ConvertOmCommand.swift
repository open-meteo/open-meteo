import Foundation
import SwiftPFor2D
import Vapor
import SwiftNetCDF

/**
 Small helper tool to convert a `om` file to NetCDF for debugging
 
 e.g. openmeteo-api convert-om /Volumes/2TB_1GBs/data/master-MRI_AGCM3_2_S/windgusts_10m_mean_linear_bias_seasonal.om --nx 1920 --transpose -o temp.nc
 
 */
struct ConvertOmCommand: Command {
    var help: String {
        return "Convert an om file to to NetCDF"
    }
    
    struct Signature: CommandSignature {
        @Argument(name: "infile", help: "Input file")
        var infile: String
        
        @Option(name: "output", short: "o", help: "Output file name. Default: ./output.nc")
        var outfile: String?
        
        @Flag(name: "transpose", help: "Transpose data to fast space")
        var transpose: Bool
        
        @Option(name: "nx", help: "Use this nx value to convert to d3")
        var nx: Int?
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let om = try OmFileReader(file: signature.infile)
        let data = try om.readAll()
        
        let oufile = signature.outfile ?? "\(signature.infile).nc"
        let ncFile = try NetCDF.create(path: oufile, overwriteExisting: true)
        try ncFile.setAttribute("TITLE", "open-meteo file convert")
        
        if let nx = signature.nx {
            let ny = om.dim0 / nx
            if signature.transpose {
                // to fast space
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: om.dim1),
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx)
                ])
                let data2 = Array2DFastTime(data: data, nLocations: om.dim0, nTime: om.dim1).transpose()
                try ncVariable.write(data2.data)
            } else {
                // fast time dimension
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "LAT", length: ny),
                    try ncFile.createDimension(name: "LON", length: nx),
                    try ncFile.createDimension(name: "time", length: om.dim1)
                ])
                try ncVariable.write(data)
            }
        } else {
            var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                try ncFile.createDimension(name: "LAT", length: om.dim1),
                try ncFile.createDimension(name: "LON", length: om.dim0),
            ])
            try ncVariable.write(data)
        }
    }
}
