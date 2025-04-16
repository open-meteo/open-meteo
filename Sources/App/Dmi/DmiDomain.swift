import Foundation

/**
 https://opendatadocs.dmi.govcloud.dk/Data/Forecast_Data_Weather_Model_HARMONIE_DINI_IG
 
 */
enum DmiDomain: String, GenericDomain, CaseIterable {
    case harmonie_arome_europe

    var grid: Gridable {
        switch self {
        case .harmonie_arome_europe:
            /*
             (key: "Nx", value: "1906")
             (key: "Ny", value: "1606")
             (key: "Latin1InDegrees", value: "55.5")
             (key: "Latin2InDegrees", value: "55.5")
             (key: "LaDInDegrees", value: "55.5")
             (key: "LoVInDegrees", value: "352")
             (key: "latitudeOfSouthernPoleInDegrees", value: "-90")
             (key: "longitudeOfSouthernPoleInDegrees", value: "0")
             (key: "gridType", value: "lambert")
             Coords(i: 0, x: 0, y: 0, latitude: 39.671, longitude: -25.421997)
             Coords(i: 3061035, x: 1905, y: 1605, latitude: 62.667614, longitude: 40.069885)
             +proj=lcc +lon_0=352.000000 +lat_0=55.500000 +lat_1=55.500000 +lat_2=55.500000 +R=6371229.000000
             */
            return ProjectionGrid(
                nx: 1906,
                ny: 1606,
                latitude: 39.671,
                longitude: -25.421997,
                dx: 2000,
                dy: 2000,
                projection: LambertConformalConicProjection(λ0: 352, ϕ0: 55.5, ϕ1: 55.5, ϕ2: 55.5, radius: 6371229)
            )
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .harmonie_arome_europe:
            return .dmi_harmonie_arome_europe
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var dtSeconds: Int {
        return 1 * 3600
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        // 60 timesteps
        return 90
    }

    var ensembleMembers: Int {
        switch self {
        case .harmonie_arome_europe:
            return 1
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .harmonie_arome_europe:
            return 3 * 3600
        }
    }

    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .harmonie_arome_europe:
            // Delay of 2:30 hours after initialisation, updates every 3 hours. Cronjob every x:35
            return t.add(hours: -2).floor(toNearestHour: 3)
        }
    }
}
