import Foundation
import OmFileFormat
import Vapor

/// Read any time from multiple files
struct OmFileSplitter {
    let domain: DomainRegistry

    let masterTimeRange: Range<Timestamp>?

    let hasYearlyFiles: Bool

    /// actually also in file
    var nLocations: Int { nx * ny * nMembers }

    let ny: Int
    let nx: Int

    /// Number of ensemble members or levels
    let nMembers: Int

    /// actually also in file
    let nTimePerFile: Int

    /// Compression ratio largly depends on chunk size for location. For small timeranges e.g. icon-d2 (121 timesteps per file the nlocation parameter effects the file size:
    /// 1 = 2.09 GB
    /// 2 = 1.15 GB
    /// 6 = 870.7 MB
    /// 12 = 739.4 MB
    /// 24 = 683.7 MB
    /// 33 = 669.2 MB
    /// 48 = 650 MB
    /// 96 = 637.1 MB
    /// Decompress performance is mostly the same, because the chunks are so small, that IO overhead is more dominant than CPU cycles
    let chunknLocations: Int

    /// With dynamic nLocation selection based on time, we get chunk locations for each domain. Minimum is set to 6, because spatial correlation does not work well with lower than 6 steps
    /// icon = 12
    /// icon-eu =  16
    /// icon-d2 = 25
    /// ecmwf = 30
    /// NOTE: carefull with reducing nchunkLocaiton, because updates will use the wrong buffer size!!!!
    static func calcChunknLocations(nTimePerFile: Int) -> Int {
        max(6, 3072 / nTimePerFile)
    }

    init<Domain: GenericDomain>(_ domain: Domain, nMembers: Int? = nil, chunknLocations: Int? = nil) {
        self.init(
            domain: domain.domainRegistry,
            nMembers: max(nMembers ?? 1, 1),
            nx: domain.grid.nx,
            ny: domain.grid.ny,
            nTimePerFile: domain.omFileLength,
            hasYearlyFiles: domain.hasYearlyFiles,
            masterTimeRange: domain.masterTimeRange,
            chunknLocations: chunknLocations
        )
    }

    init(domain: DomainRegistry, nMembers: Int, nx: Int, ny: Int, nTimePerFile: Int, hasYearlyFiles: Bool, masterTimeRange: Range<Timestamp>?, chunknLocations: Int? = nil) {
        self.domain = domain
        self.nMembers = nMembers
        self.nx = nx
        self.ny = ny
        self.nTimePerFile = nTimePerFile
        self.hasYearlyFiles = hasYearlyFiles
        self.masterTimeRange = masterTimeRange
        let nLocations = nx * ny * nMembers
        self.chunknLocations = chunknLocations ?? min(nLocations, Self.calcChunknLocations(nTimePerFile: nTimePerFile))
    }

    // optimise to use 8 MB memory, but aligned to even `chunknLocations`
    var nLocationsPerChunk: Int {
        min(nLocations, 8 * 1024 * 1024 / MemoryLayout<Float>.stride / nTimePerFile / chunknLocations * chunknLocations)
    }

    /// Prefetch all required data into memory
    func willNeed(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings, logger: Logger, httpClient: HTTPClient) async throws {
        // TODO: maybe we can keep the file handles better in scope
        let indexTime = time.time.toIndexTime()
        let nTime = indexTime.count
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var start = indexTime.lowerBound

        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
            if let offsets = indexTime.intersect(fileTime: fileTime) {
                try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                    try await reader.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                    start = fileTime.upperBound
                }
            }
        }
        if start >= indexTime.upperBound {
            return
        }

        if hasYearlyFiles {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year + 1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                    continue
                }
                let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .year, chunk: year, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
                try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                    try await reader.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                    start = fileTime.upperBound
                }
            }
        }
        if start >= indexTime.upperBound {
            return
        }
        let subring = start ..< indexTime.upperBound
        for timeChunk in subring.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk + 1) * nTimePerFile
            guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                continue
            }
            let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
            try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                try await reader.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
            }
        }
    }

    func read2D(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings, logger: Logger, httpClient: HTTPClient) async throws -> Array2DFastTime {
        let data = try await read(variable: variable, location: location, level: level, time: time, logger: logger, httpClient: httpClient)
        return Array2DFastTime(data: data, nLocations: location.count, nTime: time.time.count)
    }

    func read(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings, logger: Logger, httpClient: HTTPClient) async throws -> [Float] {
        let indexTime = time.time.toIndexTime()
        let nTime = indexTime.count
        var start = indexTime.lowerBound
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var out = [Float](repeating: .nan, count: nTime * location.count)

        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
            if let offsets = indexTime.intersect(fileTime: fileTime) {
                try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                    try await reader.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                    start = fileTime.upperBound
                }
            }
        }

        if hasYearlyFiles {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year + 1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                    continue
                }
                let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .year, chunk: year, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
                try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                    try await reader.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                    start = fileTime.upperBound
                }
            }
        }
        let delta = start - indexTime.lowerBound
        if start >= indexTime.upperBound {
            return out
        }
        let subring = start ..< indexTime.upperBound
        for timeChunk in subring.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk + 1) * nTimePerFile
            guard let offsets = subring.intersect(fileTime: fileTime) else {
                continue
            }
            let file = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: time.ensembleMember, previousDay: time.previousDay)
            try await RemoteOmFileManager.instance.with(file: file, client: httpClient, logger: logger) { reader in
                try await reader.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: (offsets.file, offsets.array.add(delta)))
            }
        }
        return out
    }

    /**
     Write new data to the archived storage and combine it with existint data.
     Updates are done in chunks to keep memory size low. Otherwise ICON update would take 4+ GB memory for just this function.
     
     TODO: should use Array3DFastTime
     */
    func updateFromTimeOriented(variable: String, array2d: Array2DFastTime, time: TimerangeDt, scalefactor: Float, compression: OmCompressionType = .pfor_delta2d_int16) async throws {
        precondition(array2d.nTime == time.count)
        precondition(array2d.nLocations == nx * ny)

        // Process at most 8 MB at once
        try await updateFromTimeOrientedStreaming3D(variable: variable, time: time, scalefactor: scalefactor, compression: compression, onlyGeneratePreviousDays: false) { yRange, xRange, _ in
            guard yRange.count == 1 || xRange.count == nx else {
                fatalError("chunk dimensions need to be either parts of X or a mutliple or X")
            }
            let start = Int(yRange.lowerBound) * nx + Int(xRange.lowerBound)
            let count = Int(yRange.count * xRange.count)
            let locationRange = start ..< start + count
            let dataRange = locationRange.multiply(array2d.nTime)
            return array2d.data[dataRange]
        }
    }

    /**
     Write new data to archived storage and combine it with existing data.
     `supplyChunk` should provide data for a couple of thousands locations at once. Upates are done streamlingly to low memory usage
     */
    func updateFromTimeOrientedStreaming3D(variable: String, time: TimerangeDt, scalefactor: Float, compression: OmCompressionType = .pfor_delta2d_int16, onlyGeneratePreviousDays: Bool, supplyChunk: (_ y: Range<UInt64>, _ x: Range<UInt64>, _ member: Range<UInt64>) async throws -> ArraySlice<Float>) async throws {
        let indexTime = time.toIndexTime()
        let indextimeChunked = indexTime.divideRoundedUp(divisor: nTimePerFile)

        /// Previous days of forecast to keep. Max 7 past days
        /// `0..<1` if previous days are not generated
        /// `1..<n` for all previous days
        let previousDaysRange: Range<Int> = onlyGeneratePreviousDays ? (1..<max(1, min(8, time.range.count / 86400))) : (0..<1)
        if previousDaysRange.isEmpty {
            return
        }

        struct WriterPerStep {
            let read: OmFileReader<MmapFile>?
            let writeFile: OmFileWriter<FileHandle>
            let write: OmFileWriterArray<Float, FileHandle>
            let writeFn: FileHandle
            let offsets: (file: CountableRange<Int>, array: CountableRange<Int>)
            let fileName: String
            let skip: Int
        }

        // open all files for all timeranges and write a header
        let writers: [WriterPerStep] = try await indextimeChunked.asyncFlatMap { timeChunk -> [WriterPerStep] in
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk + 1) * nTimePerFile
            guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                return []
            }

            return try await previousDaysRange.asyncMap { previousDay -> WriterPerStep in
                let skip = previousDay * 86400 / time.dtSeconds
                let readFile = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: 0, previousDay: previousDay)
                try readFile.createDirectory()
                let tempFile = readFile.getFilePath() + "~"
                // Another process might be updating this file right now. E.g. Second flush of GFS ensemble
                FileManager.default.waitIfFileWasRecentlyModified(at: tempFile)
                try FileManager.default.removeItemIfExists(at: tempFile)
                let fn = try FileHandle.createNewFile(file: tempFile)
                let omRead = try? await OmFileReader(mmapFile: readFile.getFilePath())

                let writeFile = OmFileWriter(fn: fn, initialCapacity: 1024 * 1024)
                let writer = try writeFile.prepareArray(
                    type: Float.self,
                    dimensions: nMembers <= 1 ? [UInt64(ny), UInt64(nx), UInt64(nTimePerFile)] : [UInt64(ny), UInt64(nx), UInt64(nMembers), UInt64(nTimePerFile)],
                    chunkDimensions: nMembers <= 1 ? [1, UInt64(chunknLocations), UInt64(nTimePerFile)] : [1, UInt64(chunknLocations), 1, UInt64(nTimePerFile)],
                    compression: compression,
                    scale_factor: scalefactor,
                    add_offset: 0
                )
                return WriterPerStep(read: omRead, writeFile: writeFile, write: writer, writeFn: fn, offsets: offsets, fileName: readFile.getFilePath(), skip: skip)
            }
        }

        let nIndexTime = indexTime.count
        guard let actualDomain = domain.getDomain() else {
            fatalError("Did not get domain")
        }

        /// Spatial files use chunks multiple time larger than the final chunk. E.g. [15,526] will be [1,15] in the final time-series file
        let spatialChunks = OmFileSplitter.calculateSpatialXYChunk(domain: actualDomain, nMembers: nMembers, nTime: 1)
        var fileData = [Float](repeating: .nan, count: spatialChunks.y * spatialChunks.x * nTimePerFile * nMembers)

        for yStart in stride(from: 0, to: UInt64(ny), by: UInt64.Stride(spatialChunks.y)) {
            for xStart in stride(from: 0, to: UInt64(nx), by: UInt64.Stride(spatialChunks.x)) {
                let yRange = yStart ..< min(yStart + UInt64(spatialChunks.y), UInt64(ny))
                let xRange = xStart ..< min(xStart + UInt64(spatialChunks.x), UInt64(nx))
                let memberRange = 0 ..< UInt64(nMembers)

                // Contains the entire time-series to be updated for a chunks of locations
                let data = try await supplyChunk(yRange, xRange, memberRange)

                // TODO check if chunks need to be reorganised for ensemble files!!!

                for writer in writers {
                    if let omRead = writer.read?.asArray(of: Float.self) {
                        // Read existing data for a range of locations
                        let dimensions = omRead.getDimensions()
                        switch dimensions.count {
                        case 2: // Old legacy file
                            if dimensions[0] == UInt64(ny * nx) {
                                // Dimensions are ok, read data. Ignores legacy ensemble files
                                let start = yRange.lowerBound * UInt64(nx) + xRange.lowerBound
                                let count = UInt64(yRange.count * xRange.count)
                                try await omRead.read(
                                    into: &fileData,
                                    range: [start ..< start + count, 0..<UInt64(nTimePerFile)]
                                )
                            }
                        case 3:
                            try await omRead.read(
                                into: &fileData,
                                range: [yRange, xRange, 0..<UInt64(nTimePerFile)]
                            )
                        case 4: // ensemble files
                            try await omRead.read(
                                into: &fileData,
                                range: [yRange, xRange, memberRange, 0..<UInt64(nTimePerFile)]
                            )
                        default:
                            fatalError("Unexpected number of dimensions (\(dimensions.count))")
                        }
                    } else {
                        // If the old file does not exist, just make sure it is filled with NaNs
                        for i in fileData.indices {
                            fileData[i] = .nan
                        }
                    }
                    // write "new" data into existing data
                    for l in 0 ..< (yRange.count * xRange.count * nMembers) {
                        for (tFile, tArray) in zip(writer.offsets.file, writer.offsets.array) {
                            if tArray < writer.skip {
                                continue
                            }
                            if data[data.startIndex + l * nIndexTime + tArray].isNaN {
                                continue
                            }
                            fileData[nTimePerFile * l + tFile] = data[data.startIndex + l * nIndexTime + tArray]
                        }
                    }

                    // Write data
                    /// TODO support for array slices
                    try writer.write.writeData(
                        array: Array(fileData[0..<yRange.count * xRange.count * nMembers * nTimePerFile]),
                        arrayDimensions: nMembers <= 1 ?
                        [UInt64(yRange.count), UInt64(xRange.count), UInt64(nTimePerFile)] :
                            [UInt64(yRange.count), UInt64(xRange.count), UInt64(nMembers), UInt64(nTimePerFile)]
                    )
                }
            }
        }

        /// Write end of file and move it in position
        for writer in writers {
            let root = try writer.writeFile.write(array: writer.write.finalise(), name: "", children: [])
            try writer.writeFile.writeTrailer(rootVariable: root)
            try writer.writeFn.close()

            // Overwrite existing file, with newly created
            try FileManager.default.moveFileOverwrite(from: "\(writer.fileName)~", to: writer.fileName)
        }
    }
}

extension OmFileSplitter {
    /// Prepare a write to store individual time-steps as spatial encoded files
    /// This makes it easier to migrate to the new file format writer
    /// If `nTime` is set, the spatial file contains TIME SERIES oriented steps as well
    static func makeSpatialWriter(domain: GenericDomain, nMembers: Int = 1, nTime: Int = 1) -> OmFileWriterHelper {
        let y = min(domain.grid.ny, 32)
        let x = min(domain.grid.nx, 1024 / y)
        
        if nTime > 1 {
            return OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx, nTime], chunks: [y, x, nTime])
        }
        return OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx], chunks: [y, x])
    }

    static func calculateSpatialXYChunk(domain: GenericDomain, nMembers: Int, nTime: Int) -> (y: Int, x: Int) {
        let splitter = OmFileSplitter(domain, nMembers: nMembers/*, chunknLocations: nMembers > 1 ? nMembers : nil*/)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        let nTimePerFile = splitter.nTimePerFile // domain.omFileLength
        let chunknLocations = splitter.chunknLocations // max(6, 3072 / nTimePerFile)
        let xchunks = max(1, min(nx, 8 * 1024 * 1024 / MemoryLayout<Float>.stride / nTimePerFile / nTime / nMembers / chunknLocations * chunknLocations))
        let ychunks = max(1, min(ny, 8 * 1024 * 1024 / MemoryLayout<Float>.stride / nTimePerFile / nTime / nMembers / xchunks))
        // print("Chunks [\(ychunks),\(xchunks)] nTimePerFile=\(nTimePerFile) chunknLocations=\(chunknLocations)")
        return (ychunks, xchunks)
    }
}

extension Range where Bound == Int {
    func toUInt64() -> Range<UInt64> {
        .init(uncheckedBounds: (UInt64(lowerBound), UInt64(upperBound)))
    }
}







extension OmFileReaderArrayProtocol where OmType == Float {
    /// Read data from file. Switch between old legacy files and new multi dimensional files.
    /// Note: `nTime` is the output array nTime. It is not the file nTime!
    /// TODO: nMembers variable is wrong if called via API controller. Aways 1
    func read3D(into: inout [Float], ny: Int, nx: Int, nTime: Int, nMembers: Int, location: Range<Int>, level: Int, timeOffsets: (file: CountableRange<Int>, array: CountableRange<Int>)) async throws {
        let dimensions = self.getDimensions()
        switch dimensions.count {
        case 2:
            // Legacy files use 2 dimensions and flatten XY coordinates
            let dim0 = Int(dimensions[0])
            // let dim1 = Int(dimensions[1])
            guard dim0 % (nx * ny) == 0 else {
                return // in case dimensions got change and do not agree anymore, ignore this file
            }
            /// Even worse, they also flatten `levels` dimensions which is used for ensemble files
            let nLevels = dim0 / (nx * ny)
            if nLevels > 1 && location.count > 1 {
                fatalError("Multi level and multi location not supported")
            }
            guard level < nLevels else {
                return
            }
            let nLocations = UInt64(location.count)
            let dim0Range = location.lowerBound * nLevels + level ..< location.lowerBound * nLevels + level + location.count
            try await read(
                into: &into,
                range: [dim0Range.toUInt64(), timeOffsets.file.toUInt64()],
                intoCubeOffset: [0, UInt64(timeOffsets.array.lowerBound)],
                intoCubeDimension: [nLocations, UInt64(nTime)]
            )
        case 3:
            // File uses dimensions [ny,nx,ntime]
            guard ny == dimensions[0], nx == dimensions[1] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound - 1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, fileTime]
            do {
                try await read(
                    into: &into,
                    range: range,
                    intoCubeOffset: [0, 0, UInt64(timeOffsets.array.lowerBound)],
                    intoCubeDimension: [UInt64(y.count), UInt64(x.count), UInt64(nTime)]
                )
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        case 4:
            // File uses dimensions [ny,nx,nLevel,ntime]
            // print("4D \(dimensions.map{Int($0)}) ny\(ny) nx\(nx) nMembers\(nMembers) l\(level)")
            guard ny == dimensions[0], nx == dimensions[1], level < dimensions[2] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound - 1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let l = UInt64(level) ..< UInt64(level + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, l, fileTime]
            do {
                try await read(
                    into: &into,
                    range: range,
                    intoCubeOffset: [0, 0, 0, UInt64(timeOffsets.array.lowerBound)],
                    intoCubeDimension: [UInt64(y.count), UInt64(x.count), 1, UInt64(nTime)]
                )
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        default:
            fatalError("ndims not implemented")
        }
    }

    /// Prefetch data for fast access. Switch between old legacy files and new multi dimensional files
    /// Note: `nTime` is the output array nTime. It is not the file nTime!
    /// /// TODO: nMembers variable is wrong if called via API controller. Aways 1
    func willNeed3D(ny: Int, nx: Int, nTime: Int, nMembers: Int, location: Range<Int>, level: Int, timeOffsets: (file: CountableRange<Int>, array: CountableRange<Int>)) async throws {
        let dimensions = self.getDimensions()
        switch dimensions.count {
        case 2:
            // Legacy files use 2 dimensions and flatten XY coordinates
            let dim0 = Int(dimensions[0])
            // let dim1 = Int(dimensions[1])
            guard dim0 % (nx * ny) == 0 else {
                return // in case dimensions got change and do not agree anymore, ignore this file
            }
            /// Even worse, they also flatten `levels` dimensions which is used for ensemble files
            let nLevels = dim0 / (nx * ny)
            if nLevels > 1 && location.count > 1 {
                fatalError("Multi level and multi location not supported")
            }
            guard level < nLevels else {
                return
            }
            let dim0Range = location.lowerBound * nLevels + level ..< location.lowerBound * nLevels + level + location.count
            try await willNeed(range: [dim0Range.toUInt64(), timeOffsets.file.toUInt64()])
        case 3:
            // File uses dimensions [ny,nx,ntime]
            guard ny == dimensions[0], nx == dimensions[1] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound - 1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, fileTime]
            do {
                try await willNeed(range: range)
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        case 4:
            // File uses dimensions [ny,nx,nLevel,ntime]
            guard ny == dimensions[0], nx == dimensions[1], level < dimensions[2] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound - 1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let l = UInt64(level) ..< UInt64(level + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, l, fileTime]
            do {
                try await willNeed(range: range)
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        default:
            fatalError("ndims not implemented")
        }
    }
}
