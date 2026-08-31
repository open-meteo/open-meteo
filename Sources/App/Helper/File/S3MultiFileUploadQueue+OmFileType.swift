import OmFileIO

extension S3MultiFileUploadQueue {
    func uploadTimeSeriesFile(_ file: OmFileType) async {
        guard shouldUploadTimeSeriesFile(file) else {
            return
        }
        await uploadMultipart(
            file: file.getFilePath(),
            objectName: "data/\(file.getRelativeFilePath())",
            lastModified: .now()
        )
    }

    private func shouldUploadTimeSeriesFile(_ file: OmFileType) -> Bool {
        switch file {
        case .domainChunk(let domain, _, .rolling, _, _, _):
            return domain == .google_weathernext2_ensemble && !endpoint.isDefaultOpenMeteoOrAws
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return !endpoint.isDefaultOpenMeteoOrAws
        case .domainChunk, .staticFile, .run:
            return true
        }
    }
}
