import OmFileFormat
import Foundation

/**
 Align concurrent access to the same data range
 */
final actor OmReaderBackendCoordinator<Backend: OmFileReaderBackendAsyncData & Sendable>: OmFileReaderBackendAsyncData {
    let backend: Backend
    private var inFlight: [Int: [CheckedContinuation<Data, any Error>]] = [:]
    
    init(backend: Backend) {
        self.backend = backend
    }
    
    func getCount() async throws -> UInt64 {
        try await backend.getCount()
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        try await backend.prefetchData(offset: offset, count: count)
    }

    func getData(offset: Int, count: Int) async throws -> Data {
        let key = offset * 2^32 + count
        guard inFlight[key] == nil else {
            return try await withCheckedThrowingContinuation { continuation in
                inFlight[key, default: []].append(continuation)
            }
        }
        inFlight[key] = []
        do {
            let data = try await backend.getData(offset: offset, count: count)
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .success(data))
            })
            return data
        } catch {
            inFlight.removeValue(forKey: key)?.forEach({
                $0.resume(with: .failure(error))
            })
            throw error
        }
    }
}
