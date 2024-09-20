import Foundation

enum GfsGraphCastDomain: String, GenericDomain, CaseIterable {
    case graphcast025
    
    var domainRegistry: DomainRegistry {
        return .ncep_gfs_graphcast025
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return .ncep_gfs025
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var runsPerDay: Int {
        return 4
    }
    
    var dtSeconds: Int {
        return 6*3600
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // GraphCast has a delay of 15 hours hours after initialisation. Cronjobs starts at 15:20
        return t.add(hours: -15).floor(toNearestHour: 6)
    }
    
    func forecastHours(run: Int) -> [Int] {
        return Array(stride(from: 6, through: 384, by: 6))
    }
    
    var levels: [Int] {
        // Switched to 13 levels from 37 on 2024-05-25. See https://github.com/NOAA-EMC/graphcast/issues/39
        //return [10, 20, 30, 50, 70, 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        return [50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000]
    }
    
    var omFileLength: Int {
        return 60
    }
    
    var grid: Gridable {
        return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
    }
}
