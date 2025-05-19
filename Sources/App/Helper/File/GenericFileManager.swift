import Foundation
import NIOConcurrencyHelpers
import Vapor

protocol GenericFileManagable: Sendable {
    func wasDeleted() -> Bool
    static func open(from: OmFileManagerReadable) throws -> Self?
}

/// Cache file handles, background close checks
/// If a file path is missing, this information is cached and checked in the background
/// This could be later extended to use file system events
/// Maybe upgraded to an actor as well. Currently uses pthread locks
struct GenericFileManager<File: GenericFileManagable>: Sendable {
    /// A file might exist and is open, or it is missing
    enum OmFileState: Sendable{
        case exists(file: File, opened: Timestamp)
        case missing(path: String, opened: Timestamp)
    }

    /// Non existing files are set to nil
    private let cached = NIOLockedValueBox<[Int: OmFileState]>(.init())

    private let statistics = NIOLockedValueBox<(count: Double, elapsed: Double, max: Double)>((0, 0, 0))

    /// Called every 2 conds from a life cycle handler on any available thread
    @Sendable func backgroundTask(application: Application) {
        let logger = application.logger
        var (count, elapsed, max) = statistics.withLockedValue({ $0 })

        let start = DispatchTime.now()
        let stats = self.secondlyCallback()
        let dt = Double((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)) / 1_000_000_000
        if dt > max {
            max = dt
        }
        elapsed += dt
        count += 1
        if count >= 10 {
            if stats.open > 0 {
                logger.info("OmFileManager checked \(stats.open) open files and \(stats.missing) missing files. Time average=\((elapsed / count).asSecondsPrettyPrint) max=\(max.asSecondsPrettyPrint)")
            }
            count = 0
            elapsed = 0
            max = 0
        }
        statistics.withLockedValue({ $0 = (count, elapsed, max) })
    }

    /// Called every couple of seconds to check for any file modifications
    func secondlyCallback() -> (open: Int, missing: Int, ejected: Int) {
        // Could be later used to expose some metrics
        var countExisting = 0
        var countMissing = 0
        var countEjected = 0

        let copy = cached.withLockedValue {
            return $0
        }
        // Close file handles after 1 hour
        let ejectionTime = Timestamp.now().subtract(hours: 1)

        for e in copy {
            switch e.value {
            case .exists(file: let file, opened: let opened):
                // Remove file from cache, if it was deleted
                if opened < ejectionTime || file.wasDeleted() {
                    cached.withLockedValue({
                        $0.removeValue(forKey: e.key)
                        countEjected += 1
                    })
                }
                countExisting += 1
            case .missing(path: let path, opened: let opened):
                // Remove file from cache, if it is now available, so the next open, will make it available
                if opened < ejectionTime || FileManager.default.fileExists(atPath: path) {
                    cached.withLockedValue({
                        _ = $0.removeValue(forKey: e.key)
                        countEjected += 1
                    })
                }
                countMissing += 1
            }
        }
        return (countExisting, countMissing, countEjected)
    }

    /// Get cached file or return nil, if the files does not exist
    public func get(_ file: OmFileManagerReadable) throws -> File? {
        let key = file.hashValue

        return try cached.withLockedValue { cached -> File? in
            if let file = cached[key] {
                switch file {
                case .exists(file: let file, opened: _):
                    return file
                case .missing:
                    return nil
                }
            }
            guard let file = try File.open(from: file) else {
                cached[key] = .missing(path: file.getFilePath(), opened: .now())
                return nil
            }
            cached[key] = .exists(file: file, opened: .now())
            return file
        }
    }
}
