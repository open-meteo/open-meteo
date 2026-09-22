import Vapor

/// Helper to generate elevation om file
actor ElevationLsmGenerator {
    var elevation: Array2D? = nil
    var lsm: Array2D? = nil
    
    func ingest(elevation: Array2D, domain: GenericDomain, application: Application, uploadS3Bucket: String?) async throws {
        if domain.surfaceElevationFileOm.exists() {
            return
        }
        self.elevation = elevation
        try await generate(domain: domain, application: application, uploadS3Bucket: uploadS3Bucket)
    }
    
    func ingest(lsm: Array2D, domain: GenericDomain, application: Application, uploadS3Bucket: String?) async throws {
        if domain.surfaceElevationFileOm.exists() {
            return
        }
        self.lsm = lsm
        try await generate(domain: domain, application: application, uploadS3Bucket: uploadS3Bucket)
    }
    
    func generate(domain: GenericDomain, application: Application, uploadS3Bucket: String?) async throws {
        guard let lsm, var elevation else {
            return
        }
        for i in elevation.data.indices {
            if lsm.data[i].isNaN || lsm.data[i] < 0.5{
                // Mark as sea grid cell
                elevation.data[i] = -999
            }
        }
        try domain.surfaceElevationFileOm.createDirectory()
        try await elevation.data.writeStaticOmFile(file: domain.surfaceElevationFileOm, grid: domain.grid, application: application, uploadS3Bucket: uploadS3Bucket)
    }
}
