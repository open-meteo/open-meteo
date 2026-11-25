import Foundation
import OmFileFormat

extension MmapFile {
    /// Set mapping advice while retaining explicit range prefetching.
    public convenience init(fn: FileHandle, mode: Mode = .readOnly, advice: MAdvice) throws {
        try self.init(fn: fn, mode: mode)
        prefetchData(offset: 0, count: count, advice: advice)
    }
}
