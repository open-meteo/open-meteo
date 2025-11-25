import Foundation

protocol GenericVariableMixable: RawRepresentableString {
}

/// Mix differnet domains together, that offer the same or similar variable set
protocol GenericReaderMixerRaw: GenericReaderProtocol {
    associatedtype Reader: GenericReaderProtocol

    var reader: [Reader] { get }
    init(reader: [Reader])
}

protocol GenericReaderMixer: GenericReaderMixerRaw {
    associatedtype Domain: GenericDomain

    static func makeReader(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> Reader?
}

struct GenericReaderMixerSameDomain<Reader: GenericReaderProtocol>: GenericReaderMixerRaw, GenericReaderProtocol {
    typealias MixingVar = Reader.MixingVar

    let reader: [Reader]
}

extension GenericReaderMixer {
    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        /// Initiaise highest resolution domain first. If `elevation` is NaN, use the elevation of the highest domain,
        var elevation = elevation

        let reader: [Reader] = try await domains.reversed().asyncCompactMap { domain -> (Reader?) in
            guard let domain = try await Self.makeReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return nil
            }
            if elevation.isNaN {
                elevation = domain.modelElevation.numeric
            }
            return domain
        }.reversed()

        guard !reader.isEmpty else {
            return nil
        }
        self.init(reader: reader)
    }
}

extension GenericReaderMixerRaw {
    var modelLat: Float {
        reader.last?.modelLat ?? .nan
    }
    var modelLon: Float {
        reader.last?.modelLon ?? .nan
    }
    var modelElevation: ElevationOrSea {
        reader.last?.modelElevation ?? .noData
    }
    var targetElevation: Float {
        reader.last?.targetElevation ?? .nan
    }
    var modelDtSeconds: Int {
        reader.last?.modelDtSeconds ?? 3600
    }

    func prefetchData(variable: Reader.MixingVar, time: TimerangeDtAndSettings) async throws {
        for reader in reader {
            try await reader.prefetchData(variable: variable, time: time)
        }
    }

    func prefetchData(variables: [Reader.MixingVar], time: TimerangeDtAndSettings) async throws {
        for variable in variables {
            try await prefetchData(variable: variable, time: time)
        }
    }

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.last?.getStatic(type: type)
    }

    func get(variable: Reader.MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        // Last reader return highest resolution data. therefore reverse iteration
        // Integrate now lower resolution models
        var data: [Float]?
        var unit: SiUnit?
        // default case, just place new data in 1:1
        for r in reader.reversed() {
            let d = try await r.get(variable: variable, time: time)
            if data == nil {
                // first iteration
                data = d.data
                unit = d.unit
            } else {
                if let unit, [.wmoCode, .dimensionless].contains(unit) {
                    data?.integrateIfNaN(d.data)
                } else {
                    data?.integrateIfNaNSmooth(d.data)
                }
                if data?.containsNaN() == false {
                    break
                }
            }
        }
        guard let data, let unit else {
            fatalError("Expected data in mixer for variable \(variable)")
        }
        return DataAndUnit(data, unit)
    }
}

extension VariableOrDerived: GenericVariableMixable where Raw: GenericVariableMixable, Derived: GenericVariableMixable {
}

extension Array where Element == Float {
    // Integrate another array if the current array has NaN values and smooth over 3 timesteps
    mutating func integrateIfNaNSmooth(_ other: [Float]) {
        assert(self.count == other.count)
        let width = 3
        var stepsSinceNaN: Int = width
        for x in other.indices.reversed() {
            stepsSinceNaN += 1
            if other[x].isNaN {
                continue
            }
            if self[x].isNaN {
                stepsSinceNaN = 0
                self[x] = other[x]
                continue
            }
            if stepsSinceNaN > width {
                continue
            }
            self[x] = (other[x] * (Float(width + 1 - stepsSinceNaN)) + self[x] * Float(stepsSinceNaN)) / Float(width+1)
        }
    }
    mutating func integrateIfNaN(_ other: [Float]) {
        assert(self.count == other.count)
        for x in other.indices {
            if other[x].isNaN || !self[x].isNaN {
                continue
            }
            self[x] = other[x]
        }
    }
    mutating func integrateIfNaNDeltaCoded(_ other: [Float]) {
        assert(self.count == other.count)
        for x in other.indices {
            if other[x].isNaN || !self[x].isNaN {
                continue
            }
            if x > 0 {
                self[x] = other[x - 1] - other[x]
            } else {
                self[x] = other[x]
            }
        }
    }
}
