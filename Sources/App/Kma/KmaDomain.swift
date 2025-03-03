import Foundation


enum KmaDomain: String, GenericDomain, CaseIterable {
    case gdps
    case ldps
    
    var grid: Gridable {
        switch self {
        case .gdps:
            return RegularGrid(nx: 2560, ny: 1920, latMin: -90+180/1920/2, lonMin: -180+360/2560/2, dx: 360/2560, dy: 180/1920)
        case .ldps:
            /**
             # Lambert Conformal (can be secant or tangent, conical or bipolar)  (grib2/tables/4/3.1.table)
               gridDefinitionTemplateNumber = 30;
               # Earth assumed spherical with radius of 6,371,229.0 m (grib2/tables/4/3.2.table)
               shapeOfTheEarth = 6;
               Nx = 602;
               Ny = 781;
               latitudeOfFirstGridPointInDegrees = 32.2569;
               longitudeOfFirstGridPointInDegrees = 121.834;
               LaDInDegrees = 38;
               LoVInDegrees = 126;
               DxInMetres = 1500;
               DyInMetres = 1500;
               # (1=0)  North Pole is on the projection plane;(2=0)  Only one projection centre is used:grib2/tables/4/3.5.table
               # flags: 00000000
               projectionCentreFlag = 0;
               iScansNegatively = 0;
               jScansPositively = 1;
               jPointsAreConsecutive = 0;
               alternativeRowScanning = 0;
               Latin1InDegrees = 30;
               Latin2 = 60000000;
               Latin2InDegrees = 60;
               latitudeOfSouthernPoleInDegrees = 0;
               longitudeOfSouthernPoleInDegrees = 0;
               gridType = lambert;
               NV = 0;
             */
            return ProjectionGrid(
                nx: 602,
                ny: 781,
                latitude: 32.2569,
                longitude: 121.834,
                dx: 1500,
                dy: 1500,
                projection: LambertConformalConicProjection(λ0: 126, ϕ0: 38, ϕ1: 30, ϕ2: 60, radius: 6371229)
            )
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .gdps:
            return .kma_gdps
        case .ldps:
            return .kma_ldps
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var dtSeconds: Int {
        switch self {
        case .gdps:
            return 3*3600
        case .ldps:
            return 1*3600
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
        case .gdps:
            // 96 steps per run + 2 days extra
            return 96 + 16
        case .ldps:
            // 49 hours per run + 1 day extra
            return 48 + 24
        }
    }
    
    var ensembleMembers: Int {
        return 1
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .gdps, .ldps:
            return 6*3600
        }
    }
    
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gdps, .ldps:
            // Delay of 3:20 hours after initialisation, updates every 6 hours. Cronjob every x:20
            // LDPS 3:40 delay
            return t.add(hours: -3).floor(toNearestHour: 6)
        }
    }
}
