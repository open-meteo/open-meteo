//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 08.11.22.
//

import Foundation

/// The required functions to implement a reader that provides derived variables
protocol GenericReaderDerived {
    associatedtype Domain: GenericDomain
    associatedtype Variable: GenericVariable, Hashable
    associatedtype Derived: RawRepresentableString
    
    var reader: GenericReaderCached<Domain, Variable> { get }
    
    init(reader: GenericReaderCached<Domain, Variable>)

    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(derived: Derived, time: TimerangeDt) throws
    
    func get(raw: Variable, time: TimerangeDt) throws -> DataAndUnit
    func prefetchData(raw: Variable, time: TimerangeDt) throws
}

extension GenericReaderDerived {
    var modelLat: Float {
        reader.modelLat
    }
    
    var modelLon: Float {
        reader.modelLon
    }
    
    var modelElevation: Float {
        reader.modelElevation
    }
    
    var modelDtSeconds: Int {
        reader.domain.dtSeconds
    }
    
    var targetElevation: Float {
        reader.targetElevation
    }
    
    var domain: Domain {
        reader.domain
    }
    
    init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReaderCached<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.init(reader: reader)
    }
    
    public init(domain: Domain, position: Range<Int>) {
        self.init(reader: GenericReaderCached<Domain, Variable>(domain: domain, position: position))
    }
    
    func prefetchData(variable: VariableOrDerived<Variable, Derived>, time: TimerangeDt) throws {
        switch variable {
        case .raw(let raw):
            return try prefetchData(raw: raw, time: time)
        case .derived(let derived):
            return try prefetchData(derived: derived, time: time)
        }
    }
    
    func get(variable: VariableOrDerived<Variable, Derived>, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let raw):
            return try get(raw: raw, time: time)
        case .derived(let derived):
            return try get(derived: derived, time: time)
        }
    }
    
    func prefetchData(variables: [VariableOrDerived<Variable, Derived>], time: TimerangeDt) throws {
        try variables.forEach { variable in
            try prefetchData(variable: variable, time: time)
        }
    }
}

/// A reader that does not modify reader. E.g. pass all reads directly to reader
protocol GenericReaderDerivedSimple: GenericReaderDerived {

}

extension GenericReaderDerivedSimple {
    func get(raw: Variable, time: TimerangeDt) throws -> DataAndUnit {
        try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: Variable, time: TimerangeDt) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
}



