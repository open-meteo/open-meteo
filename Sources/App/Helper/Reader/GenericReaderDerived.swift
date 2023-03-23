import Foundation


/// The required functions to implement a reader that provides derived variables
protocol GenericReaderDerived: GenericReaderProtocol {
    associatedtype Derived: RawRepresentableString
    associatedtype ReaderNext: GenericReaderProtocol
    
    var reader: ReaderNext { get }

    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(derived: Derived, time: TimerangeDt) throws
    
    func get(raw: ReaderNext.MixingVar, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(raw: ReaderNext.MixingVar, time: TimerangeDt) throws
}

extension GenericReaderDerived {
    var modelLat: Float {
        reader.modelLat
    }
    
    /*var domain: ReaderNext.Domain {
        return reader.domain
    }*/
    
    var modelLon: Float {
        reader.modelLon
    }
    
    var modelElevation: ElevationOrSea {
        reader.modelElevation
    }
    
    var modelDtSeconds: Int {
        reader.modelDtSeconds
    }
    
    var targetElevation: Float {
        reader.targetElevation
    }
    
    func prefetchData(variable: VariableOrDerived<ReaderNext.MixingVar, Derived>, time: TimerangeDt) throws {
        switch variable {
        case .raw(let raw):
            return try prefetchData(raw: raw, time: time)
        case .derived(let derived):
            return try prefetchData(derived: derived, time: time)
        }
    }
    
    func get(variable: VariableOrDerived<ReaderNext.MixingVar, Derived>, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let raw):
            return try get(raw: raw, time: time)
        case .derived(let derived):
            return try get(derived: derived, time: time)
        }
    }
    
    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        return try reader.getStatic(type: type)
    }
    
    func prefetchData(variables: [VariableOrDerived<ReaderNext.MixingVar, Derived>], time: TimerangeDt) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
}

/// A reader that does not modify reader. E.g. pass all reads directly to reader
protocol GenericReaderDerivedSimple: GenericReaderDerived {

}

extension GenericReaderDerivedSimple {
    func get(raw: ReaderNext.MixingVar, time: TimerangeDt) throws -> DataAndUnit {
        try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: ReaderNext.MixingVar, time: TimerangeDt) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
}



