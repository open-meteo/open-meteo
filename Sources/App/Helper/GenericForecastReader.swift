//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 08.11.22.
//

import Foundation

protocol GenericReaderDerived {
    associatedtype Domain: GenericDomain
    associatedtype Variable: GenericVariable, GenericVariableMixing2, Hashable
    associatedtype Derived: GenericVariableMixing2
    
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
    
    var modelDtSeconds: Int {
        reader.domain.dtSeconds
    }
    
    var targetElevation: Float {
        reader.targetElevation
    }
    
    init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReaderCached<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.init(reader: reader)
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



/// A generic reader that caches all file system reads
final class GenericReaderCached<Domain: GenericDomain, Variable: GenericVariable> where Variable: Hashable {
    private var cache: [Variable: DataAndUnit]
    let reader: GenericReader<Domain, Variable>
    
    /// Elevation of the grid point
    var modelElevation: Float {
        return reader.modelElevation
    }
    
    /// The desired elevation. Used to correct temperature forecasts
    var targetElevation: Float {
        return reader.targetElevation
    }
    
    /// Latitude of the grid point
    var modelLat: Float {
        return reader.modelLat
    }
    
    /// Longitude of the grid point
    var modelLon: Float {
        return reader.modelLon
    }
    
    /// Longitude of the grid point
    var domain: Domain {
        return reader.domain
    }
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = reader
        self.cache = .init()
    }
    
    func get(variable: Variable, time: TimerangeDt) throws -> DataAndUnit {
        if let value = cache[variable] {
            return value
        }
        let data = try reader.get(variable: variable, time: time)
        cache[variable] = data
        return data
    }
    
    func prefetchData(variable: Variable, time: TimerangeDt) throws {
        try reader.prefetchData(variable: variable, time: time)
    }
}

extension VariableOrDerived: GenericVariableMixing2 where Raw: GenericVariableMixing2, Derived: GenericVariableMixing2 {
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .raw(let raw):
            return raw.requiresOffsetCorrectionForMixing
        case .derived(let derived):
            return derived.requiresOffsetCorrectionForMixing
        }
    }
    
}
