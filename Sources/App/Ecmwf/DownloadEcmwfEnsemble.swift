import Foundation
import OmFileIO
import Vapor

extension DownloadEcmwfCommand {
    struct EnsembleField: Sendable {
        let variable: EcmwfVariable
        let hour: Int
        let member: Int
        let file: EcmwfLocalGribFile
        let field: EcmwfLocalGribFile.Field
    }

    struct DecodedEnsembleField: Sendable {
        let variable: EcmwfVariable
        let hour: Int
        let member: Int
        let shortName: String
        let stepType: String
        let stepRange: String
        var grib: GribArray2D
    }

    /// Cache and index complete GRIB files, then write spatial fields for conversion.
    func downloadEnsembleVariables(application: Application, signature: Signature, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfVariable], concurrent: Int, downloadConcurrent: Int, uploadQueues: [S3UploadQueue]) async throws {
        let variables = domain == .ifs01_ensemble || domain == .ifs01_ensemble_pressure_levels || domain == .ifs025_ensemble
            ? variables.filter {
                switch $0 {
                case .ocean_u_current, .ocean_v_current, .precipitation_type, .sea_ice_thickness, .sea_level_height_msl:
                    return false
                default:
                    return true
                }
            } : variables
        guard !variables.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5, chunkSizeMB: EcmwfOpenDataSource.fullFileChunkSizeMB(base: base), retryUnauthorized: true, prepareRequest: EcmwfAzureAccess.prepareRequest(base: base, client: application.dedicatedHttpClient))
        let hours = domain.getDownloadForecastSteps(run: run.hour).filter { $0 <= (signature.maxForecastHour ?? Int.max) }
        guard let lastHour = hours.last else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let files = hours.flatMap { hour in domain.getUrl(base: base, run: run, hour: hour).map { (hour: hour, url: $0) } }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let downloads = files.map { (url: $0.url, path: domain.downloadDirectory + URL(string: $0.url)!.lastPathComponent) }
        let hoursByURL = Dictionary(uniqueKeysWithValues: files.map { ($0.url, $0.hour) })
        logger.info("Scanning GRIB headers as files become available")
        let inventories = try await curl.download(files: downloads, nConcurrent: downloadConcurrent, deadLineHours: 5.5)
            .mapConcurrent(nConcurrent: concurrent) { file in
                (hour: hoursByURL[file.url]!, file: try EcmwfLocalGribFile(handle: file.handle, source: file.url))
            }
        if !domain.isPressureLevels && !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
            let elevationURL = domain.getUrl(base: base, run: run, hour: 0)[0]
            let elevationPath = domain.downloadDirectory + URL(string: elevationURL)!.lastPathComponent
            try await downloadEcmwfElevation(application: application, domain: domain, base: base, run: run, uploadQueues: uploadQueues, localGribPath: elevationPath)
        }

        let createNetcdf = signature.createNetcdf
        let generateTimeSeries = !signature.skipTimeseries
        // Process source fields before their consumers at each member/timestep.
        let order = Dictionary(uniqueKeysWithValues: variables.map { variable in
            let parameter: String
            let priority: Int
            switch variable.gribName {
            case "2t": parameter = "2t"; priority = 0
            case "2d": parameter = "2t"; priority = 1
            case "sd": parameter = "sd"; priority = 0
            case "rsn": parameter = "sd"; priority = 1
            case "t": parameter = "t"; priority = 0
            case "w": parameter = "t"; priority = 1
            case "q": parameter = "t"; priority = 2
            default: parameter = variable.gribName!; priority = 0
            }
            let level = variable.level ?? 0
            return (variable, (parameter, level, priority, variable.rawValue))
        })
        var fields = [EnsembleField]()
        var availableVariables = [EcmwfVariable]()
        for variable in variables {
            var hoursPerMember = [Set<Int>](repeating: [], count: domain.countEnsembleMember)
            for inventory in inventories {
                if inventory.hour == 0 && variable.skipHourZero { continue }
                let entries = inventory.file.fields.filter(variable.matches)
                for entry in entries {
                    if entry.shortName != variable.gribName && entries.contains(where: { $0.shortName == variable.gribName && $0.member == entry.member }) { continue }
                    guard (0..<domain.countEnsembleMember).contains(entry.member), hoursPerMember[entry.member].insert(inventory.hour).inserted else {
                        throw Abort(.badRequest, reason: "Duplicate or invalid member for \(variable) at hour \(inventory.hour)")
                    }
                    fields.append(EnsembleField(variable: variable, hour: inventory.hour, member: entry.member, file: inventory.file, field: entry))
                }
            }
            // Skip unavailable parameters, but require every expected timestep for
            // all members when a variable is present in the local files.
            guard hoursPerMember.contains(where: { !$0.isEmpty }) else { continue }
            let expectedHours = Set(hours.filter { $0 != 0 || !variable.skipHourZero })
            for (member, actualHours) in hoursPerMember.enumerated() where actualHours != expectedHours {
                logger.error("Incomplete local GRIBs: \(variable.rawValue) member \(member) has hours \(actualHours.sorted()), expected \(expectedHours.sorted())")
                throw EcmwfLocalGribFile.Failure.invalidMetadata
            }
            availableVariables.append(variable)
        }
        fields.sort {
            let a = order[$0.variable]!
            let b = order[$1.variable]!
            let aDerives = ["2t", "sd", "t"].contains(a.0)
            let bDerives = ["2t", "sd", "t"].contains(b.0)
            if aDerives != bDerives { return aDerives }
            // Keep related inputs together; each variable's hours remain ascending.
            if (a.0, a.1) != (b.0, b.1) { return (a.0, a.1) < (b.0, b.1) }
            if $0.member != $1.member { return $0.member < $1.member }
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            if $0.variable != $1.variable { return a < b }
            return $0.field.range.lowerBound < $1.field.range.lowerBound
        }
        logger.info("Reading \(availableVariables.count) variables: \(fields.count) local fields")
        // Convert each variable once all its spatial fields have been written.
        var conversionJob: Task<Void, any Error>?

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: fields.reduce(0) { $0 + $1.field.range.count }, name: "Read \(domain.rawValue)")
        let nMembers = domain.countEnsembleMember
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        guard !fields.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        let isAifs = domain == .aifs025_single || domain == .aifs025_ensemble || domain == .aifs025_ensemble_mean
        let inputs = Set(availableVariables.map(\.gribKey))
        // Map each derived output to its source field and output variable.
        var dependencies = [EcmwfVariable: EcmwfVariable]()
        var outputVariables = [EcmwfVariable: EcmwfVariable]()
        for variable in availableVariables {
            switch variable.gribName {
            case "2d" where inputs.contains("2t:2"):
                dependencies[variable] = .temperature_2m
                outputVariables[variable] = .relative_humidity_2m
            case "rsn" where !isAifs && inputs.contains("sd"):
                dependencies[variable] = .snow_depth_water_equivalent
                outputVariables[variable] = .snow_depth
            case "w", "q":
                let level = variable.level!
                if inputs.contains("t:\(level)"), variable.gribName == "w" || (isAifs && level != 10) {
                    dependencies[variable] = EcmwfVariable.from(shortName: "t", levelhPa: level)!
                    outputVariables[variable] = variable.gribName == "w" ? variable : EcmwfVariable.from(shortName: "r", levelhPa: level)!
                }
            default:
                if !["2d", "rsn", "w", "q"].contains(variable.gribName) { outputVariables[variable] = variable }
            }
        }
        let sourceUses = Dictionary(dependencies.values.map { ($0, 1) }, uniquingKeysWith: +)
        var spatialInputs = [EcmwfVariable: (data: Array2D, remaining: Int)]()
        let expectedHours = Dictionary(outputVariables.map { input, output in
            (output, hours.count - (input.skipHourZero && hours.first == 0 ? 1 : 0))
        }, uniquingKeysWith: { first, _ in first })
        // Match the converter's read blocks to avoid decompressing the same
        // spatial chunk repeatedly for neighboring blocks.
        let spatialChunks = OmFileSplitter(domain).spatialReadChunkDimensions
        var writers = [EcmwfVariable: OmSpatialMultistepWriter]()
        var writtenFields = [EcmwfVariable: Int]()
        var timings = [EcmwfVariable: (count: Int, decodeWait: Double, process: Double, write: Double)]()
        let deaverager = GribDeaverager()

        // One ordered local stream reads timesteps in parallel and keeps related
        // variable/member inputs adjacent for derivation and spatial writing.
        let decoded = fields.mapStream(nConcurrent: concurrent, nBuffered: 2 * concurrent, body: { entry -> DecodedEnsembleField in
            let field = try entry.file.withMessage(field: entry.field) { message in
                guard let shortName = message.get(attribute: "shortName"),
                      let level = message.get(attribute: "level").flatMap(Int.init),
                      let stepType = message.get(attribute: "stepType"),
                      let stepRange = message.get(attribute: "stepRange") else {
                    throw EcmwfLocalGribFile.Failure.invalidMetadata
                }
                guard entry.variable.matches(shortName: shortName, level: level) else {
                    throw EcmwfLocalGribFile.Failure.invalidMetadata
                }
                guard (message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0) == entry.member else {
                    throw EcmwfLocalGribFile.Failure.invalidMetadata
                }
                var grib = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib.load(message: message)
                grib.array.flipLatitude()
                // These inputs are instantaneous. Convert units before sharing
                // them, so RH uses Celsius and specific humidity uses g/kg.
                if stepType == "instant" {
                    if shortName == "z" { grib.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0) }
                    let fma = entry.variable.gribName == "2d" ? (multiply: Float(1), add: Float(-273.15)) : entry.variable.multiplyAdd(domain: domain, dtSeconds: domain.dtSeconds)
                    if let fma { grib.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add) }
                }
                return DecodedEnsembleField(variable: entry.variable, hour: entry.hour, member: entry.member, shortName: shortName, stepType: stepType, stepRange: stepRange, grib: grib)
            }
            await progress.add(entry.field.range.count)
            return field
        })
        // mapStream yields in input order, so deaccumulation and derivation need
        // no reorder buffers. GRIB decoding still runs concurrently ahead of this loop.
        var iterator = decoded.makeAsyncIterator()
        while true {
            let readStart = DispatchTime.now()
            guard var field = try await iterator.next() else { break }
            let decodeWait = readStart.timeElapsedSeconds()
            let processStart = DispatchTime.now()
            if field.stepType != "instant" {
                let isAccumulated = field.stepType == "accum" || field.stepType == "avg"
                var dtSeconds: Int
                if isAccumulated && field.hour == 0 {
                    field.grib.array.data = [Float](repeating: .nan, count: field.grib.array.data.count)
                    dtSeconds = domain.dtSeconds
                } else if isAccumulated {
                    var stepRange = field.stepRange
                    if field.stepType == "accum" && !stepRange.contains("-") { stepRange = "0-\(stepRange)" }
                    if domain == .aifs025_single && field.stepType == "accum" { stepRange = "0-\(field.hour)" }
                    guard let (start, end) = stepRange.splitTo2Integer(), start < end, end == field.hour else {
                        throw EcmwfLocalGribFile.Failure.invalidMetadata
                    }
                    let previousStep = await deaverager.lastStep(field.variable, field.member)
                    guard await deaverager.deaccumulateIfRequired(variable: field.variable, member: field.member, stepType: field.stepType, startStep: start, currentStep: end, array2d: &field.grib.array) else {
                        throw EcmwfLocalGribFile.Failure.invalidMetadata
                    }
                    dtSeconds = max(1, end - max(start, previousStep ?? start)) * 3600
                    if field.hour == lastHour { await deaverager.remove(variable: field.variable, member: field.member) }
                } else {
                    let start = field.stepRange.splitTo2Integer()?.0 ?? field.hour
                    dtSeconds = max(1, field.hour - start) * 3600
                }
                if field.shortName == "z" { await field.grib.array.data.multiplyAddConcurrent(multiply: 1 / 9.80665, add: 0) }
                if let fma = field.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                    await field.grib.array.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                }
            }
            if let uses = sourceUses[field.variable] {
                guard field.stepType == "instant", spatialInputs[field.variable] == nil else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                spatialInputs[field.variable] = (field.grib.array, uses)
            }
            if let source = dependencies[field.variable] {
                guard field.stepType == "instant", var input = spatialInputs.removeValue(forKey: source) else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                switch field.variable.gribName {
                case "2d":
                    field.grib.array.data = zip(input.data.data, field.grib.array.data).map(Meteorology.relativeHumidity)
                case "rsn":
                    field.grib.array.data = zip(input.data.data, field.grib.array.data).map(/)
                case "w":
                    field.grib.array.data = Meteorology.verticalVelocityPressureToGeometric(omega: field.grib.array.data, temperature: input.data.data, pressureLevel: Float(field.variable.level!))
                case "q":
                    field.grib.array.data = Meteorology.specificToRelativeHumidity(specificHumidity: field.grib.array.data, temperature: input.data.data, pressure: Float(field.variable.level!))
                default: throw EcmwfLocalGribFile.Failure.invalidMetadata
                }
                input.remaining -= 1
                if input.remaining > 0 { spatialInputs[source] = input }
            }
            guard let variable = outputVariables[field.variable] else { continue }
            let writer = writers[variable] ?? OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: logger, chunkDimensions: [spatialChunks.y, spatialChunks.x])
            writers[variable] = writer
            let processTime = processStart.timeElapsedSeconds()
            let writeStart = DispatchTime.now()
            try await writer.write(time: run.add(hours: field.hour), member: field.member, variable: variable, data: field.grib.array.data)
            let writeTime = writeStart.timeElapsedSeconds()
            var timing = timings.removeValue(forKey: variable) ?? (0, 0, 0, 0)
            timing.count += 1
            timing.decodeWait += decodeWait
            timing.process += processTime
            timing.write += writeTime
            if timing.count == expectedHours[variable]! {
                logger.info("\(variable.rawValue) member \(field.member): decodeWait=\(timing.decodeWait.asSecondsPrettyPrint), process=\(timing.process.asSecondsPrettyPrint), write=\(timing.write.asSecondsPrettyPrint)")
            } else {
                timings[variable] = timing
            }
            writtenFields[variable, default: 0] += 1
            guard writtenFields[variable] == expectedHours[variable]! * nMembers else { continue }

            let handles = try await writer.finalise()
            writers.removeValue(forKey: variable)
            writtenFields.removeValue(forKey: variable)
            try await conversionJob?.value
            conversionJob = Task {
                let conversionStart = DispatchTime.now()
                try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: 1, spatialConcurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: domain.countEnsembleMember == 1, generateTimeSeries: generateTimeSeries, ensembleMeanDomain: domain.ensembleMeanDomain, precipitationProbability: true)
                logger.info("Convert \(variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
            }
        }
        guard writers.isEmpty, spatialInputs.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        await progress.finish()
        try await conversionJob?.value
        // Publish the run only after all available variables have been converted.
        if !signature.skipTimeseries && signature.timeinterval == nil && domain.generateTimeSeries {
            for outputDomain in [domain, domain.ensembleMeanDomain].compactMap({ $0 }) {
                let data = try ModelUpdateMetaJson.update(domain: outputDomain, run: run, end: time.range.upperBound, now: .now())
                for queue in uploadQueues {
                    await queue.upload(data: data, objectName: "data/\(outputDomain.domainRegistry.rawValue)/static/meta.json", contentType: "application/json", lastModified: .now())
                }
            }
        }
        await curl.printStatistics()
    }
}
