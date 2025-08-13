/// Store remote file meta data (existence, size, last modified and eTag) in a local file `cache_file_meta.bin`
/// This data is used for faster process startup. Files are are unlikely to be modified, do not need to be revalidated immediately
/// Revalidation will still happen in the background
/// The size of meta data is fixed
enum OmHttpMetaCache {
    enum State {
        case missing(lastValidated: Timestamp)
        case available(lastValidated: Timestamp, contentLength: Int, lastModified: Timestamp?, eTag: String?)
    }
    
    static func get(url: String) -> State? {
        return OpenMeteo.fileMetaCache.get(key: url.fnv1aHash64)?.assumingMemoryBound(to: Entry.self)[0].state
    }
    
    static func set(url: String, state: State) throws {
        let entry = try Entry(state: state)
        withUnsafePointer(to: entry) { ptr in
            let buffer = UnsafeRawBufferPointer(start: ptr, count: MemoryLayout<Entry>.size)
            OpenMeteo.fileMetaCache.set(key: url.fnv1aHash64, value: buffer)
        }
    }
}


extension OmHttpMetaCache {
    struct Entry {
        let contentLength: Int
        let lastModified: Timestamp
        let lastValidated: Timestamp
        let eTag: CString48
        
        init(state: State) throws {
            switch state {
            case .missing(lastValidated: let lastValidated):
                self.contentLength = 0
                self.lastModified = Timestamp(0)
                self.lastValidated = lastValidated
                self.eTag = CString48()
            case .available(lastValidated: let lastValidated, contentLength: let contentLength, lastModified: let lastModified, eTag: let eTag):
                self.contentLength = contentLength
                self.lastModified = lastModified ?? Timestamp(0)
                self.lastValidated = lastValidated
                self.eTag = try CString48(eTag ?? "")
            }
        }
        
        init(contentLength: Int, lastModified: Timestamp, lastValidated: Timestamp, eTagString: String) throws {
            self.contentLength = contentLength
            self.lastModified = lastModified
            self.lastValidated = lastValidated
            self.eTag = try CString48(eTagString)
        }
        
        var state: State {
            if contentLength == 0 && lastModified == Timestamp(0) && eTag.string == "" {
                return .missing(lastValidated: lastValidated)
            }
            return .available(lastValidated: lastValidated, contentLength: contentLength, lastModified: lastModified.timeIntervalSince1970 == 0 ? nil : lastModified, eTag: eTag.isEmpty ? nil : eTag.string)
        }
    }
}

/// Fixed size 48 byte C string
struct CString48 {
    // Can be replaced with InlineArray with swift 6.2
    typealias CString48T = (UInt64,UInt64,UInt64,UInt64,UInt64,UInt64)
    
    private let value: CString48T
    
    enum CString48Error: Error {
        case tooLong
    }
    
    var isEmpty: Bool {
        return value == (0,0,0,0,0,0)
    }
    
    var string: String {
        return withUnsafePointer(to: value) {
            let ptr = UnsafeRawBufferPointer(start: $0, count: MemoryLayout<CString48>.size)
            let length = ptr.firstIndex(of: 0) ?? ptr.count
            return String(unsafeFrom: UnsafeRawBufferPointer(start: $0, count: length))
        }
    }
    
    public init() {
        value = (0,0,0,0,0,0)
    }
    
    public init(_ string: String) throws {
        var value: CString48T = (0,0,0,0,0,0)
        let utf8 = string.utf8
        guard string.count <= MemoryLayout<CString48T>.size else {
            throw CString48Error.tooLong
        }
        withUnsafeMutablePointer(to: &value) { ptr in
            let ptr = UnsafeMutableRawBufferPointer(start: ptr, count: MemoryLayout<CString48>.size)
            for (i,char) in utf8.enumerated() {
                ptr[i] = char
            }
        }
        self.value = value
    }
}
