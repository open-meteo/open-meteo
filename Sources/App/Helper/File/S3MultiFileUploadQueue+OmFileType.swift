import OmFileIO

extension S3MultiFileUploadQueue {
    func uploadTimeSeriesFile(_ file: OmFileType) async {
        guard shouldUploadTimeSeriesFile(file) else {
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

    func shouldUploadTimeSeriesFile(_ file: OmFileType) -> Bool {
        switch file {
        case .domainChunk(_, _, .rolling, _, _, _):
            return !excludeRollingFiles
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return !endpoint.isDefaultOpenMeteoOrAws
        case .domainChunk, .staticFile, .run:
            return true
        }
    }
}
