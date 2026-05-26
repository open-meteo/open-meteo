import Foundation
import OmFileFormat
import Vapor

/// Recursively reads the data variable of all .om files under DATA_DIRECTORY.
/// For each file it reads the center pixel [nx/2, ny/2] across all time steps.
/// Usage: openmeteo-api read-om
struct ReadOmCommand: AsyncCommand {
    var help: String { "Recursively read the data variable of all .om files in DATA_DIRECTORY" }

    struct Signature: CommandSignature {}

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let dataDirectory = OpenMeteo.dataDirectory

        logger.info("Scanning \(dataDirectory) for .om files...")

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: dataDirectory),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            logger.error("Could not enumerate directory: \(dataDirectory)")
            return
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "om" else { continue }
            let path = fileURL.path
            await readOmFile(path: path, logger: logger)
        }
    }

    private func readOmFile(path: String, logger: Logger) async {
        let now = Timestamp.now().iso8601_YYYY_MM_dd_HH_mm
        print("(\(now)) reading file \(path)")

        do {
            let fileHandle = try FileHandle.openFileReading(file: path)
            let mmapFile = try MmapFile(fn: fileHandle)
            let reader = try await OmFileReader(fn: mmapFile).expectArray(of: Float.self)

            let dims = reader.getDimensions()

            switch dims.count {
            case 2:
                logger.warning("2D file in \(path)")
                // Layout: [nLocations, nTime]
                let nLocations = Int(dims[0])
                let nTime = Int(dims[1])
                guard nLocations > 0, nTime > 0 else { return }
                for loc in 0..<nLocations {
                    _ = try await reader.read(range: [
                        UInt64(loc) ..< UInt64(loc+1),
                        0 ..< UInt64(nTime)
                    ])
                }

            case 3:
                // Layout: [ny, nx, nTime]
                let ny = Int(dims[0])
                let nx = Int(dims[1])
                let nTime = Int(dims[2])
                guard ny > 0, nx > 0, nTime > 0 else { 
                    logger.warning("Invalid dimensions in \(path)")
                    return
                }

                // full scan
                for y in 0..<ny {
                    for x in 0..<nx {
                        _ = try await reader.read(range: [
                            UInt64(y) ..< UInt64(y+1),
                            UInt64(x) ..< UInt64(x+1),
                            0 ..< UInt64(nTime)
                        ])
                    }
                }                
            default:
                logger.warning("Skipping \(path): unsupported dimension count \(dims.count)")
            }
        } catch {
            logger.warning("Failed to read \(path): \(error)")
        }
    }
}
