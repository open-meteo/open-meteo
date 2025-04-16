import Foundation

extension FileManager {
    /// Delete files older than a given date in a directory. No support for recursion.
    public func deleteFiles(direcotry: String, olderThan: Date) throws {
        let pathUrl = URL(fileURLWithPath: direcotry, isDirectory: true)
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey])
        guard let directoryEnumerator = FileManager.default.enumerator(at: pathUrl, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles) else {
            return
        }
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                let isDirectory = resourceValues.isDirectory,
                let modificationTime = resourceValues.contentModificationDate,
                let name = resourceValues.name else {
                    continue
            }
            if isDirectory {
                fatalError("unexpected directory '\(name)' in directory")
            }
            if modificationTime < olderThan {
                try removeItem(at: fileURL)
            }
        }
    }
}
