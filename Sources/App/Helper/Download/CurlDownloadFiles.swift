import Foundation
import NIOCore
import OmFileFormat
import OmFileIO

extension Curl {
    private enum FileDownloadResult: Sendable {
        case prepared(index: Int, size: Int)
        case chunk(index: Int, range: Range<Int>, data: ByteBuffer)
    }

    private struct FileDownloadState {
        let handle: FileHandle
        let size: Int
        var nextOffset = 0
        var written = 0
    }

    /// Download complete objects with one shared request limit across files.
    /// Schedule chunks in input order, prefetching up to three files. Completed
    /// chunks are written immediately at their offsets, without an ordered buffer.
    /// Existing destinations are reused; incomplete files never become visible
    /// at their final paths. Yield cached files immediately and new files in
    /// completion order. Parent directories must already exist.
    func download(files: [(url: String, path: String)], nConcurrent: Int, deadLineHours: Double? = nil) -> AsyncThrowingStream<(url: String, path: String), any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    precondition(nConcurrent > 0)
                    let files = try files.filter { file in
                        try Task.checkCancellation()
                        if FileManager.default.fileExists(atPath: file.path) {
                            logger.info("Using cached file \(file.path)")
                            if case .terminated = continuation.yield(file) { throw CancellationError() }
                            return false
                        }
                        return true
                    }
                    precondition(Set(files.map(\.path)).count == files.count, "Download destinations must be unique")
                    var states = [Int: FileDownloadState]()
                    var preparing = Set<Int>()
                    var nextFile = 0
                    var active = 0
                    let progress = TransferAmountTracker(logger: logger, totalSize: nil)
                    defer {
                        for (index, state) in states {
                            try? state.handle.close()
                            try? FileManager.default.removeItem(atPath: files[index].path + "~")
                        }
                    }
                    try await withThrowingTaskGroup(of: FileDownloadResult.self) { group in
                        while true {
                            try Task.checkCancellation()
                            while active < nConcurrent {
                                // HEAD requests share the same limit as chunk requests and
                                // prepare the next files while current chunks are transferring.
                                if nextFile < files.count && states.count + preparing.count < 3 {
                                    let index = nextFile
                                    let url = files[index].url
                                    nextFile += 1
                                    preparing.insert(index)
                                    active += 1
                                    group.addTask {
                                        let deadline = deadLineHours.map { Date().addingTimeInterval($0 * 3600) } ?? self.deadline
                                        let response = try await self.initiateDownload(url: url, range: nil, minSize: nil, method: .HEAD, cacheDirectory: nil, deadline: deadline, nConcurrent: 1, waitAfterLastModifiedBeforeDownload: self.waitAfterLastModifiedBeforeDownload)
                                        guard let size = try response.contentLength(), size >= 0 else {
                                            throw CurlError.couldNotGetContentLengthForConcurrentDownload
                                        }
                                        return .prepared(index: index, size: size)
                                    }
                                    continue
                                }
                                guard let index = states.keys.sorted().first(where: { states[$0]!.nextOffset < states[$0]!.size }),
                                      !preparing.contains(where: { $0 < index }) else { break }
                                var state = states[index]!
                                let range = state.nextOffset..<min(state.nextOffset + chunkSize, state.size)
                                state.nextOffset = range.upperBound
                                states[index] = state
                                let url = files[index].url
                                active += 1
                                group.addTask {
                                    let data = try await self.downloadInMemoryAsync(url: url, range: "\(range.lowerBound)-\(range.upperBound - 1)", minSize: range.count, cacheDirectory: nil, nConcurrent: 1, deadLineHours: deadLineHours, quiet: true)
                                    return .chunk(index: index, range: range, data: data)
                                }
                            }
                            guard let result = try await group.next() else { break }
                            active -= 1
                            switch result {
                            case .prepared(let index, let size):
                                preparing.remove(index)
                                let path = files[index].path
                                let handle = try FileHandle.createNewFile(file: path, overwrite: true, temporary: true)
                                states[index] = FileDownloadState(handle: handle, size: size)
                                logger.info("Downloading file \(files[index].url) length=\(size.bytesHumanReadable) chunkLength=\(chunkSize.bytesHumanReadable)")
                                if size == 0 {
                                    try handle.linkTemporary(file: path)
                                    try handle.close()
                                    states.removeValue(forKey: index)
                                    if case .terminated = continuation.yield(files[index]) { throw CancellationError() }
                                }
                            case .chunk(let index, let range, let data):
                                var state = states[index]!
                                try state.handle.seek(toOffset: UInt64(range.lowerBound))
                                try state.handle.write(contentsOf: data.readableBytesView)
                                state.written += data.readableBytes
                                states[index] = state
                                await progress.add(data.readableBytes)
                                if state.written == state.size {
                                    try state.handle.linkTemporary(file: files[index].path)
                                    try state.handle.close()
                                    states.removeValue(forKey: index)
                                    if case .terminated = continuation.yield(files[index]) { throw CancellationError() }
                                    logger.info("Downloaded \(files[index].path)")
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

}
