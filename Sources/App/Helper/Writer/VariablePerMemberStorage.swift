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
    
    func remove(variable: V, timestamp: Timestamp, member: Int) -> Array2D? {
        return remove(.init(variable: variable, timestamp: timestamp, member: member))
    }

    func remove(_ variable: VariableAndMember) -> Array2D? {
        return data.removeValue(forKey: variable)
    }
}

extension VariablePerMemberStorage {
    /// Get 2 variables at once and remove them from storage
    func getTwoRemoving(first: V, second: V) -> (first: Array2D, second: Array2D, timestamp: Timestamp, member: Int)? {
        for key in data.keys {
            guard
                key.variable == first,
                let secondData = data.removeValue(forKey: .init(variable: second, timestamp: key.timestamp, member: key.member)),
                let firstData = data.removeValue(forKey: key)
            else {
                continue
            }
            return (firstData, secondData, key.timestamp, key.member)
        }
        return nil
    }
    
    /// Get 2 variables at once and remove them from storage
    func getTwoRemoving(first: V, second: V, timestamp: Timestamp) -> (first: Array2D, second: Array2D, member: Int)? {
        for key in data.keys {
            guard
                key.variable == first,
                key.timestamp == timestamp,
                let secondData = data.removeValue(forKey: .init(variable: second, timestamp: timestamp, member: key.member)),
                let firstData = data.removeValue(forKey: key)
            else {
                continue
            }
            return (firstData, secondData, key.member)
        }
        return nil
    }
    
    /// Get 3 variables at once and remove them from storage
    func getThreeRemoving(first: V, second: V, third: V, timestamp: Timestamp) -> (first: Array2D, second: Array2D, third: Array2D, member: Int)? {
        for key in data.keys {
            guard
                key.variable == first,
                key.timestamp == timestamp,
                let secondKey = data.first(where: {$0.key.variable == second && $0.key.timestamp == timestamp && $0.key.member == key.member})?.key,
                let thirdKey = data.first(where: {$0.key.variable == third && $0.key.timestamp == timestamp && $0.key.member == key.member})?.key,
                let firstData = data.removeValue(forKey: key),
                let secondData = data.removeValue(forKey: secondKey),
                let thirdData = data.removeValue(forKey: thirdKey)
            else {
                continue
            }
            return (firstData, secondData, thirdData, key.member)
        }
        return nil
    }
    
    /// Get 4 variables at once and remove them from storage
    func getFourRemoving(first: V, second: V, third: V, forth: V, timestamp: Timestamp) -> (first: Array2D, second: Array2D, third: Array2D, forth: Array2D, member: Int)? {
        for key in data.keys {
            guard
                key.variable == first,
                key.timestamp == timestamp,
                let secondKey = data.first(where: {$0.key.variable == second && $0.key.timestamp == timestamp && $0.key.member == key.member})?.key,
                let thirdKey = data.first(where: {$0.key.variable == third && $0.key.timestamp == timestamp && $0.key.member == key.member})?.key,
                let forthKey = data.first(where: {$0.key.variable == forth && $0.key.timestamp == timestamp && $0.key.member == key.member})?.key,
                let firstData = data.removeValue(forKey: key),
                let secondData = data.removeValue(forKey: secondKey),
                let thirdData = data.removeValue(forKey: thirdKey),
                let forthData = data.removeValue(forKey: forthKey)
            else {
                continue
            }
            return (firstData, secondData, thirdData, forthData, key.member)
        }
        return nil
    }
}

extension VariablePerMemberStorage {
    /// Calculate wind speed and direction from U/V components for all available members for all timesteps
    /// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
    /// Removes processed variables from `self.data`
    nonisolated func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmSpatialMultistepWriter, trueNorth: [Float]? = nil) async throws {
        // Note: A for loop + remove is not thread safe due to reentrance issues
        while let (u, v, timestamp, member) = await getTwoRemoving(first: u, second: v) {
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            try await writer.write(time: timestamp, member: member, variable: outSpeedVariable, data: speed)

            if let outDirectionVariable {
                var direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                if let trueNorth {
                    direction = zip(direction, trueNorth).map({ ($0 - $1 + 360).truncatingRemainder(dividingBy: 360) })
                }
                try await writer.write(time: timestamp, member: member, variable: outDirectionVariable, data: direction)
            }
        }
    }
    
    /// Calculate wind speed and direction from U/V components for all available members for the timestep in writer
    /// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
    /// Removes processed variables from `self.data`
    nonisolated func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmSpatialTimestepWriter, trueNorth: [Float]? = nil) async throws {
        // Note: A for loop + remove is not thread safe due to reentrance issues
        while let (u, v, member) = await getTwoRemoving(first: u, second: v, timestamp: writer.time) {
            let speed = zip(u.data, v.data).map(Meteorology.windspeed)
            try await writer.write(member: member, variable: outSpeedVariable, data: speed)

            if let outDirectionVariable {
                var direction = Meteorology.windirectionFast(u: u.data, v: v.data)
                if let trueNorth {
                    direction = zip(direction, trueNorth).map({ ($0 - $1 + 360).truncatingRemainder(dividingBy: 360) })
                }
                try await writer.write(member: member, variable: outDirectionVariable, data: direction)
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
    nonisolated func correctIconSnowfallHeight(snowfallHeight: V, temperature2m: V, domainElevation: [Float], writer: OmSpatialTimestepWriter) async throws where V: GenericVariable {
        // Note: A for loop + remove is not thread safe due to reentrance issues
        while
            let t2m = await data.first(where: {$0.key.variable == temperature2m && $0.key.timestamp == writer.time}),
            var height = await remove(variable: snowfallHeight, timestamp: writer.time, member: t2m.key.member)
        {
            for i in height.data.indices {
                let freezingLevelHeight = height.data[i].isNaN ? max(0, domainElevation[i]) : height.data[i]
                let t = t2m.value.data[i]
                let newHeight = freezingLevelHeight - abs(-1 * t) * 0.7 * 100
                if newHeight <= domainElevation[i] {
                    height.data[i] = newHeight
                }
            }
            try await writer.write(member: t2m.key.member, variable: snowfallHeight, data: height.data)
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
    nonisolated func sumUpRemovingBoth(var1: V, var2: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        // Note: A for loop + remove is not thread safe due to reentrance issues
        while let (var1, var2, member) = await getTwoRemoving(first: var1, second: var2, timestamp: writer.time) {
            let sum = zip(var1.data, var2.data).map(+)
            try await writer.write(member: member, variable: outVariable, data: sum)
        }
    }
    
    /// Sum up rain, snow and graupel for total precipitation
    nonisolated func calculatePrecip(tgrp: V, tirf: V, tsnowp: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        while let (tgrp, tsnowp, tirf, member) = await getThreeRemoving(first: tgrp, second: tsnowp, third: tirf, timestamp: writer.time) {
            let precip = zip(tgrp.data, zip(tsnowp.data, tirf.data)).map({ $0 + $1.0 + $1.1 })
            try await writer.write(member: member, variable: outVariable, data: precip)
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
    
    /// Calculate snow water equivalent from snow height and liquid ratio. Limit to precipitation amount. If domain elevation is higher than snowfall height, set snowfall amount to snow
    nonisolated func calculateSnowfallWaterEquivalent(snowfall: V, liquidRatio: V, precipitation: V, snowfallHeight: V, domainElevation: [Float], outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        while let (snowfall, liquidRatio, precipitation, snowfallHeight, member) = await getFourRemoving(first: snowfall, second: liquidRatio, third: precipitation, forth: snowfallHeight, timestamp: writer.time) {
            let waterEquivalent = zip(zip(snowfall.data, zip(snowfallHeight.data, domainElevation)), zip(liquidRatio.data, precipitation.data)).map({
                let liquidRatio = $1.0
                let precipitation = $1.1
                let snowfall = $0.0
                let snowfallHeight = $0.1.0
                let domainElevation = $0.1.1
                if snowfallHeight + 200 < domainElevation {
                    return precipitation
                }
                return liquidRatio <= 0 ? 0 : min(snowfall / liquidRatio * 10, precipitation)
            })
            try await writer.write(member: member, variable: outVariable, data: waterEquivalent)
        }
    }
    
    /// Calculate snow depth from snow depth water equivalent and snow density. Removes both after use.
    /// Expects water equivalent in mm
    /// Density in kg/m3
    nonisolated func calculateSnowDepth(density: V, waterEquivalent: V, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        while let (density, water, member) = await getTwoRemoving(first: density, second: waterEquivalent, timestamp: writer.time) {
            let height = zip(water.data, density.data).map(/)
            try await writer.write(member: member, variable: outVariable, data: height)
        }
    }
    
    /// Convert pressure vertical velocity `omega` (Pa/s) to geometric vertical velocity `w` (m/s)
    /// See https://www.ncl.ucar.edu/Document/Functions/Contributed/omega_to_w.shtml
    /// Temperature in Celsius
    /// PressureLevel in hPa e.g. 1000
    /// Removes both variables after use
    nonisolated func verticalVelocityPressureToGeometric(omega: V, temperature: V, pressureLevel: Float, outVariable: GenericVariable, writer: OmSpatialTimestepWriter) async throws {
        while let (omega, temperature, member) = await getTwoRemoving(first: omega, second: temperature, timestamp: writer.time) {
            let geometric = Meteorology.verticalVelocityPressureToGeometric(omega: omega.data, temperature: temperature.data, pressureLevel: pressureLevel)
            try await writer.write(member: member, variable: outVariable, data: geometric)
        }
    }
}
