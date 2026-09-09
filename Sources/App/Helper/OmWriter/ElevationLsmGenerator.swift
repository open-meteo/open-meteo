/// Helper to generate elevation om file
actor ElevationLsmGenerator {
    var elevation: Array2D? = nil
    var lsm: Array2D? = nil
    
    func ingest(elevation: Array2D, domain: GenericDomain) async throws {
        if domain.surfaceElevationFileOm.exists() {
            return
        }
        self.elevation = elevation
        try await generate(domain: domain)
    }
    
    func ingest(lsm: Array2D, domain: GenericDomain) async throws {
        if domain.surfaceElevationFileOm.exists() {
            return
        }
        self.lsm = lsm
        try await generate(domain: domain)
    }
    
    func generate(domain: GenericDomain) async throws {
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
        try elevation.data.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid)
    }
}
