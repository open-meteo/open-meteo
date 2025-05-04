import Foundation

/**
 UK MetOffice domains from AWS rolling archive:
 https://registry.opendata.aws/met-office-global-deterministic/
 https://registry.opendata.aws/met-office-uk-deterministic/
 */
enum UkmoDomain: String, GenericDomain, CaseIterable {
    case global_deterministic_10km
    case global_ensemble_20km
    case uk_deterministic_2km
    case uk_ensemble_2km

    var grid: Gridable {
        switch self {
        case .global_deterministic_10km:
            return RegularGrid(
                nx: 2560,
                ny: 1920,
                latMin: -90,
                lonMin: -180,
                dx: 360 / 2560,
                dy: 180 / 1920
            )
        case .global_ensemble_20km:
            return RegularGrid(
                nx: 1280,
                ny: 960,
                latMin: -90,
                lonMin: -180,
                dx: 360 / 1280,
                dy: 180 / 960
            )
        case .uk_deterministic_2km, .uk_ensemble_2km:
            let projection = LambertAzimuthalEqualAreaProjection(λ0: -2.5, ϕ1: 54.9, radius: 6371229)
            return ProjectionGrid(
                nx: 1042,
                ny: 970,
                latitudeProjectionOrigion: -1036000,
                longitudeProjectionOrigion: -1158000,
                dx: 2000,
                dy: 2000,
                projection: projection
            )
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .global_deterministic_10km:
            return .ukmo_global_deterministic_10km
        case .uk_deterministic_2km:
            return .ukmo_uk_deterministic_2km
        case .global_ensemble_20km:
            return .ukmo_global_ensemble_20km
        case .uk_ensemble_2km:
            return .ukmo_uk_ensemble_2km
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var dtSeconds: Int {
        switch self {
        case .global_deterministic_10km, .uk_deterministic_2km, .global_ensemble_20km, .uk_ensemble_2km:
            return 3600
        }
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        switch self {
        case .global_deterministic_10km:
            return 168 + 1 + 24
        case .uk_deterministic_2km:
            return 55 + 24
        case .global_ensemble_20km:
            return 198 + 1
        case .uk_ensemble_2km:
            return 126 + 24
        }
    }

    var ensembleMembers: Int {
        switch self {
        case .uk_deterministic_2km, .global_deterministic_10km:
            return 1
        case .global_ensemble_20km:
            return 18
        case .uk_ensemble_2km:
            return 3
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .global_deterministic_10km, .global_ensemble_20km:
            return 6 * 3600
        case .uk_deterministic_2km,. uk_ensemble_2km:
            return 3600
        }
    }

    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .global_deterministic_10km, .global_ensemble_20km:
            // Delay of 9:00 hours after initialisation, updates every 6 hours
            return t.add(hours: -9).floor(toNearestHour: 6)
        case .uk_deterministic_2km, .uk_ensemble_2km:
            // Delay of 6:00 hours after initialisation, updates every hour
            return t.add(hours: -6).floor(toNearestHour: 1)
        }
    }

    var modelNameOnS3: String {
        switch self {
        case .global_deterministic_10km:
            return "global-deterministic-10km"
        case .uk_deterministic_2km:
            return "uk-deterministic-2km"
        case .global_ensemble_20km:
            return "global-ensemble"
        case .uk_ensemble_2km:
            return "uk-ensemble"
        }
    }

    var s3Bucket: String {
        switch self {
        case .global_deterministic_10km, .uk_deterministic_2km:
            return "met-office-atmospheric-model-data"
        case .global_ensemble_20km:
            return "met-office-global-ensemble-model-data"
        case .uk_ensemble_2km:
            return "met-office-uk-ensemble-model-data"
        }
    }

    /**
     Return forecast hours for each run as a unix Timestamp. Works better for 15 minutely steps.
     */
    func forecastSteps(run: Timestamp) -> [Timestamp] {
        switch self {
        case .global_deterministic_10km:
            if run.hour % 12 == 6 {
                // shortend run
                return (Array(0..<54) + stride(from: 54, through: 60, by: 3)).map({ run.add(hours: $0) })
            }
            return (Array(0..<54) + stride(from: 54, to: 144, by: 3) + stride(from: 144, through: 168, by: 6)).map({ run.add(hours: $0) })
        case .uk_deterministic_2km:
            // every 3 hours, 55 hours otherwise 13 hours
            return Array(TimerangeDt(start: run, nTime: run.hour % 3 == 0 ? 55 : 13, dtSeconds: 3600))
        case .uk_ensemble_2km:
            return Array(TimerangeDt(start: run, nTime: 127, dtSeconds: 3600))
        case .global_ensemble_20km:
            let through = run.hour % 12 == 6 ? 180 : 198
            return (Array(0..<54) + stride(from: 54, to: 144, by: 3) + stride(from: 144, through: through, by: 6)).map({ run.add(hours: $0) })
        }
    }

    var runsPerDay: Int {
        switch self {
        case .global_deterministic_10km, .global_ensemble_20km:
            return 4
        case .uk_deterministic_2km, .uk_ensemble_2km:
            return 24
        }
    }
}
