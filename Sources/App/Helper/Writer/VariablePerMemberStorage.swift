import Foundation


/// Thread safe storage for downloading GRIB messages. Can be used to post process data.
actor VariablePerMemberStorage<V: Hashable & Sendable> {
    struct VariableAndMember: Hashable, Sendable {
        let variable: V
        let timestamp: Timestamp
        let member: Int

        func with(variable: V, timestamp: Timestamp? = nil) -> VariableAndMember {
            .init(variable: variable, timestamp: timestamp ?? self.timestamp, member: self.member)
        }

        var timestampAndMember: TimestampAndMember {
            return .init(timestamp: timestamp, member: member)
        }
    }

    struct TimestampAndMember: Equatable {
        let timestamp: Timestamp
        let member: Int
    }

    var data = [VariableAndMember: Array2D]()

    init(data: [VariableAndMember: Array2D] = [VariableAndMember: Array2D]()) {
        self.data = data
    }

    func set(variable: V, timestamp: Timestamp, member: Int, data: Array2D) {
        self.data[.init(variable: variable, timestamp: timestamp, member: member)] = data
    }

    func get(variable: V, timestamp: Timestamp, member: Int) -> Array2D? {
        return data[.init(variable: variable, timestamp: timestamp, member: member)]
    }

    func get(_ variable: VariableAndMember) -> Array2D? {
        return data[variable]
    }
    
    func getAndForget(variable: V, timestamp: Timestamp, member: Int) -> Array2D? {
        return getAndForget(.init(variable: variable, timestamp: timestamp, member: member))
    }

    func getAndForget(_ variable: VariableAndMember) -> Array2D? {
        return data.removeValue(forKey: variable)
    }
}

extension VariablePerMemberStorage {
    /// Calculate wind speed and direction from U/V components for all available members for all timesteps
    /// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
    /// Removes processed variables from `self.data`
    func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmSpatialMultistepWriter, trueNorth: [Float]? = nil) async throws {
        
        for uKey in data.keys {
            guard uKey.variable == u else {
                continue
            }
            let vKey = uKey.with(variable: v)
            guard let v = data.removeValue(forKey: vKey), let u = data.removeValue(forKey: uKey) else {
                continue
            }
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            try await writer.write(time: uKey.timestamp, member: uKey.member, variable: outSpeedVariable, data: speed)

            if let outDirectionVariable {
                var direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                if let trueNorth {
                    direction = zip(direction, trueNorth).map({ ($0 - $1 + 360).truncatingRemainder(dividingBy: 360) })
                }
                try await writer.write(time: uKey.timestamp, member: uKey.member, variable: outDirectionVariable, data: direction)
            }
        }
    }
    
    /// Calculate wind speed and direction from U/V components for all available members for the timestep in writer
    /// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
    /// Removes processed variables from `self.data`
    func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmSpatialTimestepWriter, trueNorth: [Float]? = nil) async throws {
        
        for uKey in data.keys {
            guard uKey.variable == u && uKey.timestamp == writer.time else {
                continue
            }
            let vKey = uKey.with(variable: v)
            guard let v = data.removeValue(forKey: vKey), let u = data.removeValue(forKey: uKey) else {
                continue
            }
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            try await writer.write(member: uKey.member, variable: outSpeedVariable, data: speed)

            if let outDirectionVariable {
                var direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                if let trueNorth {
                    direction = zip(direction, trueNorth).map({ ($0 - $1 + 360).truncatingRemainder(dividingBy: 360) })
                }
                try await writer.write(member: uKey.member, variable: outDirectionVariable, data: direction)
            }
        }
    }

    /// Generate elevation file
    /// - `elevation`: in metres
    /// - `landMask` 0 = sea, 1 = land. Fractions below 0.5 are considered sea.
    func generateElevationFile(elevation: V, landmask: V, domain: GenericDomain) throws {
        let elevationFile = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: elevationFile.getFilePath()) {
            return
        }
        guard var elevation = self.data.first(where: { $0.key.variable == elevation })?.value.data,
              let landMask = self.data.first(where: { $0.key.variable == landmask })?.value.data else {
            return
        }

        try elevationFile.createDirectory()
        for i in elevation.indices {
            if elevation[i] >= 9000 {
                fatalError("Elevation greater 90000")
            }
            if landMask[i] < 0.5 {
                // mask sea
                elevation[i] = -999
            }
        }
        #if Xcode
        try Array2D(data: elevation, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: domain.surfaceElevationFileOm.getFilePath().replacingOccurrences(of: ".om", with: ".nc"))
        #endif

        try elevation.writeOmFile2D(file: elevationFile.getFilePath(), grid: domain.grid, createNetCdf: false)
    }
    
    /// Lower freezing level or snowfall height below grid-cell elevation to adjust data to mixed terrain
    /// Use temperature to estimate freezing level height below ground. This is consistent with GFS
    /// https://github.com/open-meteo/open-meteo/issues/518#issuecomment-1827381843
    /// Note: snowfall height is NaN if snowfall height is at ground level
    func correctIconSnowfallHeight(snowfallHeight: V, temperature2m: V, domainElevation: [Float], writer: OmSpatialTimestepWriter) async throws where V: GenericVariable {
        for (key, t2m) in data {
            guard
                key.variable == temperature2m,
                key.timestamp == writer.time,
                let snowfallHeightIndex = data.firstIndex(where: { $0.key.variable == snowfallHeight && $0.key.timestamp == writer.time && $0.key.member == key.member })
            else {
                continue
            }
            var height = data.remove(at: snowfallHeightIndex).value
            
            for i in height.data.indices {
                let freezingLevelHeight = height.data[i].isNaN ? max(0, domainElevation[i]) : height.data[i]
                let t = t2m.data[i]
                let newHeight = freezingLevelHeight - abs(-1 * t) * 0.7 * 100
                if newHeight <= domainElevation[i] {
                    height.data[i] = newHeight
                }
            }
            try await writer.write(member: key.member, variable: snowfallHeight, data: height.data)
        }
    }

    /// Sum up 2 variables
    func sumUp(var1: V, var2: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        for (t, handles) in self.data
            .groupedPreservedOrder(by: { $0.key.timestampAndMember }){
            guard
                t.timestamp == writer.time,
                let var1 = handles.first(where: { $0.key.variable == var1 }),
                let var2 = handles.first(where: { $0.key.variable == var2 }) else {
                continue
            }
            let sum = zip(var1.value.data, var2.value.data).map(+)
            try await writer.write(member: t.member, variable: outVariable, data: sum)
        }
    }
    
    /// Sum up 2 variables, and remove them from storage
    func sumUpRemovingBoth(var1: V, var2: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        for (key, _) in data {
            guard
                key.variable == var1,
                key.timestamp == writer.time,
                let var2Index = data.firstIndex(where: { $0.key.variable == var2 && $0.key.timestamp == writer.time && $0.key.member == key.member }),
                let var1 = data.removeValue(forKey: key)
            else {
                continue
            }
            let var2 = data.remove(at: var2Index).value
            let sum = zip(var1.data, var2.data).map(+)
            try await writer.write(member: key.member, variable: outVariable, data: sum)
        }
    }
    
    /// Sum up rain, snow and graupel for total precipitation
    func calculatePrecip(tgrp: V, tirf: V, tsnowp: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        for (t, handles) in self.data.groupedPreservedOrder(by: { $0.key.timestampAndMember }) {
            guard
                t.timestamp == writer.time,
                let tgrp = handles.first(where: { $0.key.variable == tgrp }),
                let tsnowp = handles.first(where: { $0.key.variable == tsnowp }),
                let tirf = handles.first(where: { $0.key.variable == tirf }) else {
                continue
            }
            let precip = zip(tgrp.value.data, zip(tsnowp.value.data, tirf.value.data)).map({ $0 + $1.0 + $1.1 })
            try await writer.write(member: t.member, variable: outVariable, data: precip)
        }
    }
    
    /// Snowfall is given in percent. Multiply with precipitation to get the amount. Note: For whatever reason it can be `-50%`. Used for GFS
    func calculateSnowfallAmount(precipitation: V, frozen_precipitation_percent: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        for (t, handles) in self.data.groupedPreservedOrder(by: { $0.key.timestampAndMember }) {
            guard
                t.timestamp == writer.time,
                let precipitation = handles.first(where: { $0.key.variable == precipitation }),
                let frozen_precipitation_percent = handles.first(where: { $0.key.variable == frozen_precipitation_percent }) else {
                continue
            }
            let snowfall = zip(frozen_precipitation_percent.value.data, precipitation.value.data).map({
                max($0 / 100 * $1 * 0.7, 0)
            })
            try await writer.write(member: t.member, variable: outVariable, data: snowfall)
        }
    }
    
    /// Calculate relative humidity. Removed dewpoint from storage afterwards
    func calculateRelativeHumidity(temperature: V, dewpoint: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        for (key, t2m) in data {
            guard
                key.variable == temperature,
                key.timestamp == writer.time,
                let dewpointIndex = data.firstIndex(where: { $0.key.variable == dewpoint && $0.key.timestamp == writer.time && $0.key.member == key.member })
            else {
                continue
            }
            let dewpoint = data.remove(at: dewpointIndex).value
            let rh = zip(t2m.data, dewpoint.data).map(Meteorology.relativeHumidity)
            try await writer.write(member: key.member, variable: outVariable, data: rh)
        }
    }
}
