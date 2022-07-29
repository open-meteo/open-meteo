import Foundation


struct IconWaveMixer {
    let reader: [IconWaveReader]
    let modelLat: Float
    let modelLon: Float
    let time: TimerangeDt
    
    public init(lat: Float, lon: Float, time: Range<Timestamp>) throws {
        let hourly = time.range(dtSeconds: 3600)
        reader = try IconWaveDomain.allCases.compactMap {
            return try IconWaveReader(domain: $0, lat: lat, lon: lon, time: hourly)
        }
        guard let highresModel = reader.last else {
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        self.time = hourly
        modelLat = highresModel.modelLat
        modelLon = highresModel.modelLon
    }
    
    func prefetchData(variables: [IconWaveVariable]) throws {
        try variables.forEach { variable in
            try reader.forEach { reader in
                try reader.prefetchData(variable: variable)
            }
        }
    }
    
    func get(variable: IconWaveVariable) throws -> DataAndUnit {
        // Read data from available domains
        let datas = try reader.map {
            try $0.get(variable: variable)
        }
        // global domain
        var first = datas.first!
        // default case, just place new data in 1:1
        for d in datas.dropFirst() {
            for x in d.indices {
                if d[x].isNaN {
                    continue
                }
                first[x] = d[x]
            }
        }
        return DataAndUnit(first, variable.unit)
    }
}

struct IconWaveReader {
    let domain: IconWaveDomain
    
    /// Grid index in data files
    let position: Int
    let time: TimerangeDt
    
    let modelLat: Float
    let modelLon: Float
    
    /// If set, use new data files
    let omFileSplitter: OmFileSplitter
    
    public init?(domain: IconWaveDomain, lat: Float, lon: Float, time: TimerangeDt) throws {
        guard let gridpoint = try domain.grid.findPointInSea(lat: lat, lon: lon, elevationFile: domain.elevationFile) else {
            return nil
        }
        self.domain = domain
        self.position = gridpoint.gridpoint
        self.time = time
        
        omFileSplitter = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        
        (modelLat, modelLon) = domain.grid.getCoordinates(gridpoint: gridpoint.gridpoint)
    }
    
    func prefetchData(variable: IconWaveVariable) throws {
        try omFileSplitter.willNeed(variable: variable.rawValue, location: position, time: time)
    }
    
    /// Interpolate 3h GWAM to 1 hourly data to match with EWAM
    func get(variable: IconWaveVariable) throws -> [Float] {
        if time.dtSeconds == domain.dtSeconds {
            return try omFileSplitter.read(variable: variable.rawValue, location: position, time: time)
        }
        if time.dtSeconds > domain.dtSeconds {
            fatalError()
        }
        
        let interpolationType = variable.interpolation
        
        let timeLow = time.forInterpolationTo(modelDt: domain.dtSeconds).expandLeftRight(by: domain.dtSeconds*(interpolationType.padding-1))
        let dataLow = try omFileSplitter.read(variable: variable.rawValue, location: position, time: timeLow)
        
        var data = [Float]()
        data.reserveCapacity(time.count)
        switch interpolationType {
        case .linear:
            for t in time {
                let index = t.timeIntervalSince1970 / domain.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / domain.dtSeconds
                let fraction = Float(t.timeIntervalSince1970 % domain.dtSeconds) / Float(domain.dtSeconds)
                let A = dataLow[index]
                let B = index+1 >= dataLow.count ? A : dataLow[index+1]
                let h = A * (1-fraction) + B * fraction
                /// adjust it to scalefactor, otherwise interpolated values show more level of detail
                data.append(round(h * variable.scalefactor) / variable.scalefactor)
            }
        case .nearest:
            fatalError("Not implemented")
        case .solar_backwards_averaged:
            fatalError("Not implemented")
        case .hermite:
            for t in time {
                let index = t.timeIntervalSince1970 / domain.dtSeconds - timeLow.range.lowerBound.timeIntervalSince1970 / domain.dtSeconds
                let fraction = Float(t.timeIntervalSince1970 % domain.dtSeconds) / Float(domain.dtSeconds)
                
                let B = dataLow[index]
                let A = index-1 < 0 ? B : dataLow[index-1].isNaN ? B : dataLow[index-1]
                let C = index+1 >= dataLow.count ? B : dataLow[index+1].isNaN ? B : dataLow[index+1]
                let D = index+2 >= dataLow.count ? C : dataLow[index+2].isNaN ? B : dataLow[index+2]
                let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
                let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
                let c = -A/2.0 + C/2.0
                let d = B
                let h = a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d
                /// adjust it to scalefactor, otherwise interpolated values show more level of detail
                data.append(round(h * variable.scalefactor) / variable.scalefactor)
            }
        case .hermite_backwards_averaged:
            fatalError("Not implemented")
        }
        return data
    }
}


extension TimerangeDt {
    func forInterpolationTo(modelDt: Int) -> TimerangeDt {
        let start = range.lowerBound.floor(toNearest: modelDt)
        let end = range.upperBound.ceil(toNearest: modelDt)
        return TimerangeDt(start: start, to: end, dtSeconds: modelDt)
    }
    func expandLeftRight(by: Int) -> TimerangeDt {
        return TimerangeDt(start: range.lowerBound.add(-1*by), to: range.upperBound.add(by), dtSeconds: dtSeconds)
    }
}
