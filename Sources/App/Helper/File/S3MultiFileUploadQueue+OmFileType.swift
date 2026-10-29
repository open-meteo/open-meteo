import OmFileIO

extension S3MultiFileUploadQueue {
    func uploadTimeSeriesFile(_ file: OmFileType, includeRolling: Bool = false) async {
        guard Self.shouldUploadTimeSeriesFile(file, endpoint: endpoint, includeRolling: includeRolling) else {
            return
        }
        await uploadMultipart(
            file: file.getFilePath(),
            objectName: "data/\(file.getRelativeFilePath())",
            lastModified: .now()
        )
    }

    static func shouldUploadTimeSeriesFile(_ file: OmFileType, endpoint: S3BucketEndpoint, includeRolling: Bool = false) -> Bool {
        switch file {
        case .domainChunk(let domain, _, .rolling, _, _, _):
            return includeRolling || (domain == .google_weathernext2_ensemble && !endpoint.isDefaultOpenMeteoOrAws)
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return !endpoint.isDefaultOpenMeteoOrAws
        case .domainChunk, .staticFile, .run:
            return true
        }
    }
}
