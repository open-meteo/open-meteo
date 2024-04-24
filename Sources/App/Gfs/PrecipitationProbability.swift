import Foundation
import SwiftPFor2D

/**
 Group all probabilities variables for all domains in one enum
 */
enum ProbabilityVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case precipitation_probability
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        return 1
    }
    
    var interpolation: ReaderInterpolation {
        return .hermite(bounds: 0...100)
    }
    
    var unit: SiUnit {
        return .percentage
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

extension VariablePerMemberStorage {
    /// Calculate precipitation >0.1mm/h probability
    func calculatePrecipitationProbability(precipitationVariable: V, domain: GenericDomain) throws -> [GenericVariableHandle] {
        // Usefull probs, precip >0.1, >1, clouds <20%, clouds 20-50, 50-80, >80, snowfall eq >0.1, >1.0, wind >20kt, temp <0, temp >25
        // However, more and more probabilities takes up more resources than analysing raw member data
        return try self.data.filter({$0.key.variable == precipitationVariable}).grouped(by: {$0.key.timestamp}).compactMap { (timestamp, handles) in
            let nMember = handles.count
            guard nMember > 1 else {
                return nil
            }
            
            var precipitationProbability01 = [Float](repeating: 0, count: domain.grid.count)
            // Note: does not consider domain dt switching
            let threshold = Float(0.1) * Float(domain.dtHours)
            for (v, data) in handles {
                guard v.variable == precipitationVariable else {
                    continue
                }
                for i in data.data.indices {
                    if data.data[i] >= threshold {
                        precipitationProbability01[i] += 1
                    }
                }
            }
            precipitationProbability01.multiplyAdd(multiply: 100/Float(nMember), add: 0)
            let variable = ProbabilityVariable.precipitation_probability
            /// Do not set `chunknLocations` because only 1 member is stored
            let nLocationsPerChunk = OmFileSplitter(domain, chunknLocations: nil).nLocationsPerChunk
            let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
            let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: precipitationProbability01)
            return GenericVariableHandle(
                variable: variable,
                time: timestamp,
                member: 0,
                fn: fn,
                skipHour0: false
            )
        }
    }
}
