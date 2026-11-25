import OmFileIO

extension S3MultiFileUploadQueue {
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
