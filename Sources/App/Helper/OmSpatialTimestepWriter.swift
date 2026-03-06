import OmFileFormat
import Foundation

/**
 multiple files
 data_spatial/<domain>/latest-run.json
 data_spatial/<domain>/current-run.json
 data_spatial/<domain>/<run>/meta.json -> contains list of variables + timestamps
 data_spatial/<domain>/<run>/<timestamp>.om
 
 data_spatial/<domain>/latest-run_model-levels.json
 data_spatial/<domain>/current-run_model-levels.json
 data_spatial/<domain>/<run>/meta_model-levels.json -> contains list of variables + timestamps
 data_spatial/<domain>/<run>/<timestamp>_model-levels.om (only late icon runs)
 */



/// Write multiple spatial oriented variables into one file per time-step
actor OmSpatialTimestepWriter {
    var variables: [VariableWithOffset] = .init()
    var filename: String?
    var writer: OmFileWriter<FileHandle>?
    let domain: GenericDomain
    let run: Timestamp
    let time: Timestamp
    let realm: String?
    var fn: FileHandle?
    let storeOnDisk: Bool
    
    /// Separate ensemble mean+spread calculator and writer. Data is automatically ingested on write() call
    /// AWS upload and finalise also process ensemble mean
    let ensembleMean: (writer: OmSpatialTimestepWriter, calculator: EnsembleMeanCalculator)?
    
    struct VariableWithOffset {
        let variable: any GenericVariable
        let member: Int
        let writer: OmFileWriterArray<Float, FileHandle>
        
        var omFileNameWithMember: String {
            return member > 0 ? "\(variable.omFileName.file)_member\(member.zeroPadded(len: 2))" : variable.omFileName.file
        }
    }
    
    /// Create new OM file in data_spatial directory for a given run, timestamp and realm
    /// `realm` can be used if upper or model levels are generated at a later stage
    init(domain: GenericDomain, run: Timestamp, time: Timestamp, storeOnDisk: Bool, realm: String?, ensembleMeanDomain: GenericDomain? = nil) {
        self.writer = nil
        self.domain = domain
        self.run = run
        self.time = time
        self.realm = realm
        self.storeOnDisk = storeOnDisk
        self.fn = nil
        self.ensembleMean = ensembleMeanDomain.map { ens in
            (OmSpatialTimestepWriter(domain: ens, run: run, time: time, storeOnDisk: false, realm: nil), EnsembleMeanCalculator())
        }
    }
    
    var variableString: [String] {
        variables.map(\.omFileNameWithMember).sorted()
    }
    
    
    /// Check if a given variable and member is present
    func contains<V: GenericVariable & Equatable>(variable: V, member: Int) -> Bool {
        return self.variables.contains { $0.variable as? V == variable && $0.member == member }
    }
    
    /// Get existing writer or init new instance
    func getWriter() throws -> OmFileWriter<FileHandle> {
        if let writer = writer {
            return writer
        }
        let fn: FileHandle
        if storeOnDisk, let directorySpatial = domain.domainRegistry.directorySpatial {
            let path = "\(directorySpatial)\(run.format_directoriesYYYYMMddhhmm)/"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            let realm = realm.map { "_\($0)" } ?? ""
            let filename = "\(path)\(time.iso8601_YYYY_MM_dd_HHmm)\(realm).om"
            let fileTemp = "\(filename)~"
            try FileManager.default.removeItemIfExists(at: fileTemp)
            fn = try FileHandle.createNewFile(file: fileTemp)
            self.filename = filename
        } else {
            let file = "\(OpenMeteo.tempDirectory)\(Int.random(in: 0..<Int.max)).om"
            try FileManager.default.removeItemIfExists(at: file)
            fn = try FileHandle.createNewFile(file: file)
            try FileManager.default.removeItem(atPath: file)
            filename = nil
        }
        let writer = OmFileWriter(fn: fn, initialCapacity: 4 * 1024)
        self.writer = writer
        self.fn = fn
        return writer
    }
    
    func contains(member: Int, variable: any GenericVariable) -> Bool {
        return variables.contains(where: { "\($0.variable)" == "\(variable)" && $0.member == member})
    }
    
    /// Write a single variable to the file
    func write(member: Int, variable: any GenericVariable, data: [Float], compressionType: OmCompressionType = .pfor_delta2d_int16) async throws {
        if contains(member: member, variable: variable) {
            return
        }
        
        let writer = try getWriter()
        
        let y = min(domain.grid.ny, 32)
        let x = min(domain.grid.nx, 1024 / y)
        let dimensions = [domain.grid.ny, domain.grid.nx]
        let chunks = [y, x]
        guard dimensions.reduce(1, *) == data.count else {
            fatalError(#function + ": Array size \(data.count) does not match dimensions \(dimensions)")
        }
        let arrayWriter = try writer.prepareArray(
            type: Float.self,
            dimensions: dimensions.map(UInt64.init),
            chunkDimensions: chunks.map(UInt64.init),
            compression: compressionType,
            scale_factor: variable.scalefactor,
            add_offset: 0
        )
        try arrayWriter.writeData(array: data)
        self.variables.append(VariableWithOffset(variable: variable, member: member, writer: arrayWriter))
        
        await ensembleMean?.calculator.ingest(variable: variable, spreadVariable: variable.asSpreadVariableGeneric, data: data)
    }
    
    /// Finalize and upload
    func finalise(completed: Bool, validTimes: [Timestamp], uploadS3Bucket: String?, uploadMeta: Bool = true) async throws -> [GenericVariableHandle] {
        let handles = try await finalise()
        guard handles.count > 0 else {
            return []
        }
        try await writeMetaAndAWSUpload(completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket, uploadMeta: uploadMeta)
        return handles
    }
    
    func writeMetaAndAWSUpload(completed: Bool, validTimes: [Timestamp], uploadS3Bucket: String?, uploadMeta: Bool = true, forceAllTimestampUpload: Bool = false) async throws {
        try await ensembleMean?.writer.writeMetaAndAWSUpload(completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket, uploadMeta: uploadMeta, forceAllTimestampUpload: forceAllTimestampUpload)
        
        // Upload to AWS S3
        // The single OM file will be uploaded + meta JSON files
        guard let filename, let directorySpatial = domain.domainRegistry.directorySpatial else {
            // return early for temporary files that do not need a meta.json
            return
        }
        
        let meta = DataSpatialJson(
            reference_time: run.toDate(),
            last_modified_time: Date(),
            completed: completed,
            valid_times: validTimes.map(\.iso8601_YYYY_MM_dd_HH_mmZ),
            variables: self.variableString,
            crs_wkt: domain.grid.crsWkt2
        )
        let realm = realm.map { "_\($0)" } ?? ""
        let path = "\(directorySpatial)\(run.format_directoriesYYYYMMddhhmm)/"
        let metaRunMeta = "\(path)meta\(realm).json"
        let metaInProgress = "\(directorySpatial)in-progress\(realm).json"
        let metaLatest = "\(directorySpatial)latest\(realm).json"
        
        try meta.writeTo(path: metaRunMeta)
        
        /// Only update `in-progress.json` if there is no older run currently generating files. E.g. HRRR downloads 2 runs in parallel with ~20 minutes overlap
        let canUpdateInProgress = completed || (try? DataSpatialJson.readFrom(path: metaInProgress).sameRunOrOlderThan5Minutes(run: run)) ?? true
        
        if canUpdateInProgress {
            try meta.writeTo(path: metaInProgress)
        }
        if completed {
            try meta.writeTo(path: metaLatest)
        }
        
        guard let uploadS3Bucket else {
            return
        }
        let domain = domain
        let run = run
        let time = time
        try await domain.domainRegistry.parseBucket(uploadS3Bucket).foreachConcurrent(nConcurrent: 4) { (bucket, profile) in
            let destDomain = "s3://\(bucket)/data_spatial/\(domain.domainRegistry.rawValue)/"
            let destRun = "\(destDomain)\(run.format_directoriesYYYYMMddhhmm)/"
            let destFile = "\(destRun)\(time.iso8601_YYYY_MM_dd_HHmm)\(realm).om"
            
            if forceAllTimestampUpload {
                // Sync entire run directory
                try Process.awsSync(src: directorySpatial, dest: destDomain, profile: profile)
            } else {
                try Process.awsCopy(src: filename, dest: destFile, profile: profile)
            }
            
            if uploadMeta {
                let destMeta = "\(destRun)meta\(realm).json"
                try Process.awsCopy(src: metaRunMeta, dest: destMeta, profile: profile)
                if canUpdateInProgress {
                    let destInProgress = "\(destDomain)in-progress\(realm).json"
                    try Process.awsCopy(src: metaInProgress, dest: destInProgress, profile: profile)
                }
                if completed {
                    let destLatest = "\(destDomain)latest\(realm).json"
                    try Process.awsCopy(src: metaLatest, dest: destLatest, profile: profile)
                    
                    // Additional sync to make sure everything is uploaded
                    try Process.awsSync(src: directorySpatial, dest: destDomain, profile: profile)
                }
            }
        }
    }
    
    /// Finalize the time step
    func finalise() async throws -> [GenericVariableHandle] {
        let ensembleMean = try await finaliseEnsembleMean()
        
        guard let writer, let fn else {
            return ensembleMean
        }
        
        guard variables.count > 0 else {
            if let filename = filename {
                try FileManager.default.removeItemIfExists(at: "\(filename)~")
            }
            return ensembleMean
        }
        
        let runTime = try writer.write(value: run.timeIntervalSince1970, name: "forecast_reference_time", children: [])
        let validTime =  try writer.write(value: time.timeIntervalSince1970, name: "valid_time", children: [])
        let coordinates = try writer.write(value: "lat lon", name: "coordinates", children: [])
        let createdAt = try writer.write(value: Timestamp.now().timeIntervalSince1970, name: "created_at", children: [])
        let crs = try writer.write(value: domain.grid.crsWkt2, name: "crs_wkt", children: [])
        
        // Write LUTs of all variables
        let writerFinalised = try self.variables.map {
            try $0.writer.finalise()
        }
        // Write variable meta data
        let variablesOffset = try zip(variables, writerFinalised).map {
            let unit = try writer.write(value: $0.0.variable.unit.abbreviation, name: "unit", children: [])
            return try writer.write(array: $0.1, name: $0.0.omFileNameWithMember, children: [unit])
        }
        let root = try writer.writeNone(name: "", children: variablesOffset + [crs, runTime, validTime, coordinates, createdAt])
        try writer.writeTrailer(rootVariable: root)
        
        if let filename {
            try FileManager.default.moveFileOverwrite(from: "\(filename)~", to: filename)
        }
        
        let reader = try await OmFileReader(fn: try MmapFile(fn: fn))
        let time = self.time
        let dtSeconds = domain.dtSeconds
        let variablesAndMember: [(variable: any GenericVariable, member: Int)] = variables.map { ($0.variable, $0.member) }
        let domain = domain
        let handles = try await variablesAndMember.enumerated().asyncMap { (i, variable) in
            guard let arrayReader = try await reader.getChild(UInt32(i))?.asArray(of: Float.self) else {
                fatalError("Could not read variable \(variable.variable.omFileName.file) as Float array")
            }
            return GenericVariableHandle(variable: variable.variable, time: TimerangeDt(start: time, nTime: 1, dtSeconds: dtSeconds), member: variable.member, reader: arrayReader, domain: domain)
        }
        return handles + ensembleMean
    }
    
    private func finaliseEnsembleMean() async throws -> [GenericVariableHandle] {
        guard let ensembleMean else {
            return []
        }
        try await ensembleMean.calculator.calculateAndWrite(to: ensembleMean.writer)
        return try await ensembleMean.writer.finalise()
    }
}


/// Write mutliple timesteps
actor OmSpatialMultistepWriter {
    var writer = [OmSpatialTimestepWriter]()
    let storeOnDisk: Bool
    let realm: String?
    let run: Timestamp
    let domain: GenericDomain
    let ensembleMeanDomain: GenericDomain?
    
    /// `realm` can be used if upper or model levels are generated at a later stage
    init(domain: GenericDomain, run: Timestamp, storeOnDisk: Bool, realm: String?, ensembleMeanDomain: GenericDomain? = nil) {
        self.storeOnDisk = storeOnDisk
        self.realm = realm
        self.domain = domain
        self.run = run
        self.ensembleMeanDomain = ensembleMeanDomain
    }
    
    /// Write a single variable to the file
    func write(time: Timestamp, member: Int, variable: any GenericVariable, data: [Float], compressionType: OmCompressionType = .pfor_delta2d_int16) async throws {
        try await getWriter(time: time).write(member: member, variable: variable, data: data, compressionType: compressionType)
    }
    
    func getWriter(time: Timestamp) throws -> OmSpatialTimestepWriter {
        if let writer = writer.first(where: {$0.time == time}) {
            return writer
        }
        let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: time, storeOnDisk: storeOnDisk, realm: realm)
        self.writer.append(writer)
        return writer
    }
    
    /// Finalise the time step and return all handles
    /// If not validTimes are given, use all timestamps from the underlaying writer
    func finalise(completed: Bool, validTimes: [Timestamp]?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let validTimes = validTimes ?? writer.map(\.time)
        // Only upload META JSON for the last timestamp
        let lastTimestamp = writer.last?.time
        let handles = try await writer.asyncFlatMap({
            let isLast = $0.time == lastTimestamp
            return try await $0.finalise(completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket, uploadMeta: isLast)
        })
        return handles
    }
    
    /// Finalize the time step
    func finalise() async throws -> [GenericVariableHandle] {
        let handles = try await writer.asyncFlatMap({
            return try await $0.finalise()
        })
        return handles
    }
    
    // Upload om files to AWS from mutliple timesteps
    func writeMetaAndAWSUpload(completed: Bool, validTimes: [Timestamp], uploadS3Bucket: String?, uploadMeta: Bool = true) async throws {
        try await writer.last?.writeMetaAndAWSUpload(completed: completed, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket, uploadMeta: uploadMeta, forceAllTimestampUpload: true)
    }
}

