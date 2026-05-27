import Foundation
import OmFileFormat
import Vapor

/// Recursively reads the data variable of all .om files under DATA_DIRECTORY.
/// For each file it reads the center pixel [nx/2, ny/2] across all time steps.
/// Usage: openmeteo-api validate-om-files
struct ValidateOmFilesCommand: AsyncCommand {
    var help: String { "Recursively read the data variable of all .om files in DATA_DIRECTORY." }

    struct Signature: CommandSignature {
        @Option(name: "directory", short: "d", help: "Read all files in this directory")
        var directory: String?
        
        @Flag(name: "full-scan", short: "f", help: "Perform full read. Otherwise only reads the center pixel.")
        var fullScan: Bool
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        let dataDirectory = signature.directory ?? OpenMeteo.dataDirectory

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

        for case let fileURL as URL in AnySequence(enumerator) {
            guard fileURL.pathExtension == "om" else { continue }
            let path = fileURL.path
            await readOmFile(path: path, logger: logger, fullScan: signature.fullScan)
        }
    }

    private func readOmFile(path: String, logger: Logger, fullScan: Bool) async {
        logger.info("Reading file \(path)", metadata: ["time": "\(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)"])

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
                if fullScan {
                    for loc in 0..<nLocations {
                        _ = try await reader.read(range: [
                            UInt64(loc) ..< UInt64(loc+1),
                            0 ..< UInt64(nTime)
                        ])
                    }
                } else {
                    let center = nLocations / 2
                    _ = try await reader.read(range: [
                        UInt64(center) ..< UInt64(center + 1),
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
                if fullScan {
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
                } else {
                    let cy = ny / 2
                    let cx = nx / 2
                    _ = try await reader.read(range: [
                        UInt64(cy) ..< UInt64(cy + 1),
                        UInt64(cx) ..< UInt64(cx + 1),
                        0 ..< UInt64(nTime)
                    ])
                }
            default:
                logger.warning("Skipping \(path): unsupported dimension count \(dims.count)")
            }
        } catch {
            logger.warning("Failed to read \(path): \(error)")
        }
    }
}
