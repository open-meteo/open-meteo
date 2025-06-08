
enum MeteoSwissDomain: String, GenericDomain, CaseIterable {
    case icon_ch1
    case icon_ch2

    var domainRegistry: DomainRegistry {
        switch self {
        case .icon_ch1:
            return .meteoswiss_icon_ch1
        case .icon_ch2:
            return .meteoswiss_icon_ch2
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
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

    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // 30 min delay
        return t.with(hour: t.hour)
    }
    
    var forecastLength: Int {
        switch self {
        case .icon_ch1:
            return 33
        case .icon_ch2:
            return 120
        }
    }

    var omFileLength: Int {
        switch self {
        case .icon_ch1:
            return 48
        case .icon_ch2:
            return 144
        }
    }

    var grid: Gridable {
        let projection = RotatedLatLonProjection(latitude: 43.0, longitude: 190.0)
        switch self {
        case .icon_ch1:
            /*
             dx: 0.01
             dy: 0.01
             xmin: -6.86
             xmax: 4.83
             ymin: -4.46
             ymax: 3.39
             north_pole_lon: 190.0
             north_pole_lat: 43.0
             */
            return ProjectionGrid(
                nx: Int((6.86+4.83)/0.01+1),
                ny: Int((4.46+3.39)/0.01+1),
                latitudeProjectionOrigion: -4.46,
                longitudeProjectionOrigion: -6.86,
                dx: 0.01,
                dy: 0.01,
                projection: projection
            )
        case .icon_ch2:
            /*
             dx: 0.02
             dy: 0.02
             xmin: -6.82
             xmax: 4.8
             ymin: -4.42
             ymax: 3.36
             north_pole_lon: 190.0
             north_pole_lat: 43.0
             */
            return ProjectionGrid(
                nx: Int((6.82+4.8)/0.02+1),
                ny: Int((4.42+3.36)/0.02+1),
                latitudeProjectionOrigion: -4.42,
                longitudeProjectionOrigion: -6.82,
                dx: 0.02,
                dy: 0.02,
                projection: projection
            )
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .icon_ch1:
            return 3*3600
        case .icon_ch2:
            return 6*3600
        }
    }
    
    var collection: String {
        switch self {
        case .icon_ch1:
            "ch.meteoschweiz.ogd-forecasting-icon-ch1"
        case .icon_ch2:
            "ch.meteoschweiz.ogd-forecasting-icon-ch2"
        }
    }
}
