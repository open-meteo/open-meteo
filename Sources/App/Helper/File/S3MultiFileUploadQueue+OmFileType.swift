import OmFileIO

extension S3MultiFileUploadQueue {
    func uploadTimeSeriesFile(_ file: OmFileType, includeRolling: Bool = false) async {
        guard Self.shouldUploadTimeSeriesFile(file, endpoint: endpoint, includeRolling: includeRolling) else {
            return
        }
        let commitImmediately: Bool
        if case .domainChunk(_, _, .rolling, _, _, _) = file {
            commitImmediately = true
        } else {
            commitImmediately = false
        }
        await uploadMultipart(
            file: file.getFilePath(),
            objectName: "data/\(file.getRelativeFilePath())",
            lastModified: .now(),
            commitImmediately: commitImmediately
        )
    }

    static func shouldUploadTimeSeriesFile(_ file: OmFileType, endpoint: S3BucketEndpoint, includeRolling: Bool = false) -> Bool {
        switch file {
        case .domainChunk(_, _, .rolling, _, _, _):
            return includeRolling
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return !endpoint.isDefaultOpenMeteoOrAws
        case .domainChunk, .staticFile, .run:
            return true
        }
    }
}
