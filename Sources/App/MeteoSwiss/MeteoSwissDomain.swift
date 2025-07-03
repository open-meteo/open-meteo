
enum MeteoSwissDomain: String, GenericDomain, CaseIterable {
    case icon_ch1
    case icon_ch2
    
    case icon_ch1_ensemble
    case icon_ch2_ensemble

    var domainRegistry: DomainRegistry {
        switch self {
        case .icon_ch1:
            return .meteoswiss_icon_ch1
        case .icon_ch2:
            return .meteoswiss_icon_ch2
        case .icon_ch1_ensemble:
            return .meteoswiss_icon_ch1_ensemble
        case .icon_ch2_ensemble:
            return .meteoswiss_icon_ch2_ensemble
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            return .meteoswiss_icon_ch1
        case .icon_ch2, .icon_ch2_ensemble:
            return .meteoswiss_icon_ch2
        }
    }

    var hasYearlyFiles: Bool {
        return false
    }
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        return 3600
    }
    var isGlobal: Bool {
        return false
    }

    /// Based on the current time, guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            // 1:15 delay, update every 3 hours
            return t.subtract(hours: 1, minutes: 15).with(hour: 3)
        case .icon_ch2, .icon_ch2_ensemble:
            // 2:30 delay, update every 6 hours
            return t.subtract(hours: 2, minutes: 30).with(hour: 6)
        }
    }
    
    var forecastLength: Int {
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            return 33
        case .icon_ch2, .icon_ch2_ensemble:
            return 120
        }
    }

    var omFileLength: Int {
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            return 48
        case .icon_ch2, .icon_ch2_ensemble:
            return 144
        }
    }

    var grid: Gridable {
        let projection = RotatedLatLonProjection(latitude: 43.0, longitude: 190.0)
        // Domain area selected by OpenMeteo to exclude
        // ICON CH2: 2 pixel at the boarder contain invalid data. Additional 18 pixel are removed because the model is not stable at the border
        let border: Float = 20*0.02
        let x: ClosedRange<Float> = -6.86 + border ... 4.82 - border
        let y: ClosedRange<Float> = -4.46 + border ... 3.38 - border
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            let dx: Float = 0.01, dy: Float = 0.01
            return ProjectionGrid(
                nx: Int((x.upperBound - x.lowerBound) / dx) + 1,
                ny: Int((y.upperBound - y.lowerBound) / dy) + 1,
                latitudeProjectionOrigion: y.lowerBound,
                longitudeProjectionOrigion: x.lowerBound,
                dx: dx,
                dy: dy,
                projection: projection
            )
        case .icon_ch2, .icon_ch2_ensemble:
            let dx: Float = 0.02, dy: Float = 0.02
            return ProjectionGrid(
                nx: Int((x.upperBound - x.lowerBound) / dx) + 1,
                ny: Int((y.upperBound - y.lowerBound) / dy) + 1,
                latitudeProjectionOrigion: y.lowerBound,
                longitudeProjectionOrigion: x.lowerBound,
                dx: dx,
                dy: dy,
                projection: projection
            )
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            return 3*3600
        case .icon_ch2, .icon_ch2_ensemble:
            return 6*3600
        }
    }
    
    var collection: String {
        switch self {
        case .icon_ch1, .icon_ch1_ensemble:
            "ch.meteoschweiz.ogd-forecasting-icon-ch1"
        case .icon_ch2, .icon_ch2_ensemble:
            "ch.meteoschweiz.ogd-forecasting-icon-ch2"
        }
    }
    
    var ensembleMembers: Int {
        switch self {
        case .icon_ch1:
            return 1
        case .icon_ch2:
            return 1
        case .icon_ch1_ensemble:
            return 11
        case .icon_ch2_ensemble:
            return 21
        }
    }
}
