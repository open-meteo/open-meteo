import Foundation
import SwiftPFor2D


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
        // GFS has a delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
        return t.with(hour: ((t.hour - 3 + 24) % 24) / 6 * 6)
    }
    
    /// `SecondFlush` is used to download the hours 390-840 from GFS ensemble 0.5° which are 18 hours later available
    func forecastHours(run: Int) -> [Int] {
        return Array(stride(from: 6, through: 240, by: 6))
    }

    var levels: [Int] {
        return [10, 15, 20, 30, 40, 50, 70, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
    }
    
    var omFileLength: Int {
        return 60
    }
    
    var grid: Gridable {
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
    }
}
