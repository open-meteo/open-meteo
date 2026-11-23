import Foundation
import NIOCore
import OmFileFormat
import OmFileIO
#if os(Linux)
import Glibc
#endif

extension Curl {
    private enum FileDownloadResult: Sendable {
        case prepared(index: Int, size: Int)
        case chunk(index: Int, size: Int)
    }

    private enum FileWriteError: NonRetryError {
        case failed(errno: Int32)
    }

    private struct FileDownloadState {
        let handle: FileHandle
        let size: Int
        var nextOffset = 0
        var written = 0
    }

    /// Download complete objects with one shared request limit across files.
    /// Schedule chunks in input order, prefetching up to three files. Response
    /// fragments are written directly at their offsets without buffering chunks.
    /// Existing destinations are reused; incomplete files never become visible
    /// at their final paths. Yield cached files immediately and new files in
    /// completion order. Handles are positioned at zero and owned by the consumer.
    /// Parent directories must already exist.
    func download(files: [(url: String, path: String)], nConcurrent: Int, deadLineHours: Double? = nil) -> AsyncThrowingStream<(url: String, handle: FileHandle), any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    precondition(nConcurrent > 0)
                    let files = try files.filter { file in
                        try Task.checkCancellation()
                        if FileManager.default.fileExists(atPath: file.path) {
                            logger.info("Using cached file \(file.path)")
                            if case .terminated = continuation.yield((url: file.url, handle: try FileHandle.openFileReading(file: file.path))) { throw CancellationError() }
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
                                let handle = state.handle
                                group.addTask {
                                    let deadline = deadLineHours.map { Date().addingTimeInterval($0 * 3600) } ?? self.deadline
                                    let timeout = TimeoutTracker(logger: self.logger, deadline: deadline)
                                    while true {
                                        try Task.checkCancellation()
                                        do {
                                            let response = try await self.initiateDownload(url: url, range: "\(range.lowerBound)-\(range.upperBound - 1)", minSize: range.count, cacheDirectory: nil, deadline: deadline, nConcurrent: 1, quiet: true, waitAfterLastModifiedBeforeDownload: nil)
                                            try CurlMemoryDownloadError.validateRange(status: Int(response.status.code), contentRange: response.headers.first(name: "Content-Range"), expected: range)
                                            if let length = try response.contentLength() {
                                                try CurlMemoryDownloadError.validateSize(current: 0, additional: length, limit: range.count)
                                            }
                                            // A retry overwrites this range from the beginning. Other
                                            // workers write disjoint ranges using independent offsets.
                                            var received = 0
                                            for try await fragment in response.body {
                                                try Task.checkCancellation()
                                                guard Date() <= deadline else { throw CurlError.timeoutReached }
                                                try CurlMemoryDownloadError.validateSize(current: received, additional: fragment.readableBytes, limit: range.count)
                                                try fragment.withUnsafeReadableBytes { bytes in
                                                    var written = 0
                                                    while written < bytes.count {
                                                        let count = pwrite(handle.fileDescriptor, bytes.baseAddress!.advanced(by: written), bytes.count - written, off_t(range.lowerBound + received + written))
                                                        if count < 0 && errno == EINTR { continue }
                                                        guard count > 0 else { throw FileWriteError.failed(errno: count < 0 ? errno : EIO) }
                                                        written += count
                                                    }
                                                }
                                                received += fragment.readableBytes
                                                self.totalBytesTransfered.add(fragment.readableBytes, ordering: .relaxed)
                                                await progress.add(fragment.readableBytes)
                                            }
                                            guard received == range.count else { throw CurlError.sizeTooSmall }
                                            try await response.waitAfterLastModified(logger: self.logger, wait: self.waitAfterLastModified)
                                            return .chunk(index: index, size: received)
                                        } catch {
                                            try await timeout.check(error: error)
                                        }
                                    }
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
                                    try handle.seek(toOffset: 0)
                                    states.removeValue(forKey: index)
                                    if case .terminated = continuation.yield((url: files[index].url, handle: handle)) { throw CancellationError() }
                                }
                            case .chunk(let index, let size):
                                var state = states[index]!
                                state.written += size
                                states[index] = state
                                if state.written == state.size {
                                    try state.handle.linkTemporary(file: files[index].path)
                                    try state.handle.seek(toOffset: 0)
                                    states.removeValue(forKey: index)
                                    if case .terminated = continuation.yield((url: files[index].url, handle: state.handle)) { throw CancellationError() }
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
