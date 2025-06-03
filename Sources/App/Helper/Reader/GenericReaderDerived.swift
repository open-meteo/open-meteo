import Foundation
import Vapor

/// The required functions to implement a reader that provides derived variables
protocol GenericReaderDerived: GenericReaderProtocol {
    associatedtype Derived: RawRepresentableString
    associatedtype ReaderNext: GenericReaderProtocol

    var reader: ReaderNext { get }

    func get(derived: Derived, time: TimerangeDtAndSettings) async throws -> DataAndUnit
    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) async throws

    func get(raw: ReaderNext.MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit
    func prefetchData(raw: ReaderNext.MixingVar, time: TimerangeDtAndSettings) async throws
}

/// Parameters for tilted radiation calculation
struct GenericReaderOptions {
    /// Tilt of a solar panel for GTI calculation. 0° horizontal, 90° vertical.
    var tilt: Float

    /// Azimuth of a solar panel for GTI calculation. 0° south, -90° east, 90° west
    var azimuth: Float
    
    let logger: Logger
    
    let httpClient: HTTPClient

    public init(tilt: Float? = nil, azimuth: Float? = nil, logger: Logger, httpClient: HTTPClient) throws {
        /// Tilt of a solar panel for GTI calculation. 0° horizontal, 90° vertical. Throws out of bounds error.
        if let tilt {
            guard tilt.isNaN || (tilt >= 0 && tilt <= 90) else {
                throw ForecastapiError.generic(message: "Parameter `&tilt=` must be within 0° and 90°")
            }
        }
        /// Azimuth of a solar panel for GTI calculation. 0° south, -90° east, 90° west. Throws out of bounds error.
        if let azimuth {
            guard azimuth.isNaN || (azimuth >= -180 && azimuth <= 180) else {
                throw ForecastapiError.generic(message: "Parameter `&azimuth=` must be within -180° and 180°")
            }
        }
        self.tilt = tilt ?? 0
        self.azimuth = azimuth ?? 0
        self.logger = logger
        self.httpClient = httpClient
    }
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

    func prefetchData(variable: VariableOrDerived<ReaderNext.MixingVar, Derived>, time: TimerangeDtAndSettings) async throws {
        switch variable {
        case .raw(let raw):
            return try await prefetchData(raw: raw, time: time)
        case .derived(let derived):
            return try await prefetchData(derived: derived, time: time)
        }
    }

    func get(variable: VariableOrDerived<ReaderNext.MixingVar, Derived>, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch variable {
        case .raw(let raw):
            return try await get(raw: raw, time: time)
        case .derived(let derived):
            return try await get(derived: derived, time: time)
        }
    }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.getStatic(type: type)
    }

    func prefetchData(variables: [VariableOrDerived<ReaderNext.MixingVar, Derived>], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            try await prefetchData(variable: variable, time: time)
        }
    }
}

/// A reader that does not modify reader. E.g. pass all reads directly to reader
protocol GenericReaderDerivedSimple: GenericReaderDerived {
}

extension GenericReaderDerivedSimple {
    func get(raw: ReaderNext.MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        try await reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: ReaderNext.MixingVar, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }
}
