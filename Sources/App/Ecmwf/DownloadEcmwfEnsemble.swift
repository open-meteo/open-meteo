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
        var array2d: Array2D
    }

    struct AccumulatedVariable: Hashable, Sendable {
        let variable: EcmwfVariable
        let shortName: String
        let stepType: String
        let stepRange: String
    }

    private struct EnsembleVariableMember: Hashable {
        let variable: EcmwfVariable
        let member: Int
    }

    /// Cache and index complete GRIB files, then assemble time series for conversion.
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
        let inventories = try await downloadLocalGribFiles(curl: curl, domain: domain, base: base, run: run, hours: hours, concurrent: concurrent, downloadConcurrent: downloadConcurrent)
        if !domain.isPressureLevels && !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
            let elevationURL = domain.getUrl(base: base, run: run, hour: 0)[0]
            let elevationPath = domain.downloadDirectory + URL(string: elevationURL)!.lastPathComponent
            try await downloadEcmwfElevation(application: application, domain: domain, base: base, run: run, uploadQueues: uploadQueues, localGribPath: elevationPath)
        }

        let createNetcdf = signature.createNetcdf
        let generateTimeSeries = !signature.skipTimeseries
        let priorityVariables: [EcmwfVariable] = [
            .temperature_2m, .relative_humidity_2m, .temperature_2m_max, .temperature_2m_min,
            .shortwave_radiation,
            .wind_u_component_10m, .wind_v_component_10m,
            .wind_u_component_100m, .wind_v_component_100m, .wind_gusts_10m,
            .precipitation, .showers, .snowfall_water_equivalent,
            .snow_depth, .snow_depth_water_equivalent,
            .surface_temperature, .pressure_msl,
            .cloud_cover, .cloud_cover_high, .cloud_cover_low, .cloud_cover_mid, .cape,
            .soil_moisture_0_to_7cm, .soil_moisture_100_to_255cm,
            .soil_moisture_28_to_100cm, .soil_moisture_7_to_28cm,
            .soil_temperature_0_to_7cm, .soil_temperature_100_to_255cm,
            .soil_temperature_28_to_100cm, .soil_temperature_7_to_28cm,
            .total_column_integrated_water_vapour, .runoff, .precipitation_type,
            .ocean_u_current, .ocean_v_current, .sea_ice_thickness, .sea_level_height_msl
        ]
        let priorities = Dictionary(uniqueKeysWithValues: priorityVariables.enumerated().map { ($0.element, $0.offset) })
        // Keep calculator inputs together at each member/timestep, in priority order.
        let order = Dictionary(uniqueKeysWithValues: variables.map { variable in
            let parameter: String
            let inputPriority: Int
            switch variable.gribName {
            case "2t": parameter = "2t"; inputPriority = 0
            case "2d": parameter = "2t"; inputPriority = 1
            case "rsn": parameter = "sd"; inputPriority = 0
            case "sd": parameter = "sd"; inputPriority = 1
            case "t": parameter = "t"; inputPriority = 0
            case "w": parameter = "t"; inputPriority = 1
            case "q": parameter = "t"; inputPriority = 2
            default: parameter = variable.gribName!; inputPriority = 0
            }
            let groupVariable: EcmwfVariable
            switch variable {
            case .relative_humidity_2m: groupVariable = .temperature_2m
            case .snow_depth_water_equivalent: groupVariable = .snow_depth
            default: groupVariable = variable
            }
            let priority = priorities[groupVariable] ?? priorityVariables.count
            return (variable, (priority, parameter, variable.level ?? 0, inputPriority, variable.rawValue))
        })
        var fields = [EnsembleField]()
        var availableVariableCount = 0
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
            availableVariableCount += 1
        }
        fields.sort {
            let a = order[$0.variable]!
            let b = order[$1.variable]!
            // Keep related inputs together; each variable's hours remain ascending.
            if (a.0, a.1, a.2) != (b.0, b.1, b.2) { return (a.0, a.1, a.2) < (b.0, b.1, b.2) }
            if $0.member != $1.member { return $0.member < $1.member }
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            if $0.variable != $1.variable { return a < b }
            return $0.field.range.lowerBound < $1.field.range.lowerBound
        }
        logger.info("Reading \(availableVariableCount) variables: \(fields.count) local fields")
        // Convert each variable once all its member time series have been written.
        var conversionJob: Task<Void, any Error>?

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: fields.reduce(0) { $0 + $1.field.range.count }, name: "Read \(domain.rawValue)")
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        guard !fields.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        let isAifs = domain == .aifs025_single || domain == .aifs025_ensemble || domain == .aifs025_ensemble_mean
        let snowDepthCalculator = SnowDepthCalculator()
        let verticalVelocityCalculator = VerticalVelocityCalculator<EcmwfVariable>()
        let specificHumidityCalculator = SpecificHumidityCalculator<EcmwfVariable>()
        let rhCalculator = RelativeHumidityCalculator(outVariable: EcmwfVariable.relative_humidity_2m)
        let chunks = OmFileSplitter(domain).spatialReadChunkDimensions
        let deaverager = GribDeaverager()
        let inMemoryAccumulated = VariablePerMemberStorage<AccumulatedVariable>()
        let positiveHours = hours.filter { $0 > 0 }
        let nextHours = Dictionary(uniqueKeysWithValues: zip([0] + positiveHours, positiveHours))
        var series = [EnsembleVariableMember: (timesteps: [(time: Int, data: [Float])], process: Double)]()
        var handles = [EcmwfVariable: [GenericVariableHandle]]()
        defer { conversionJob?.cancel() }

        // Workers decode, deaccumulate and derive spatial fields. The consumer
        // assembles complete member time series for interpolation and conversion.
        let processed = fields.mapStream(nConcurrent: concurrent, body: { entry -> [(variable: EcmwfVariable, member: Int, hour: Int, data: [Float], process: Double)] in
            var field = try entry.file.withMessage(field: entry.field) { message in
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
                return DecodedEnsembleField(variable: entry.variable, hour: entry.hour, member: entry.member, shortName: shortName, stepType: stepType, stepRange: stepRange, array2d: grib.array)
            }
            var decoded = [(variable: EcmwfVariable, member: Int, hour: Int, data: [Float], process: Double)]()
            let processStart = DispatchTime.now()
            let start = field.stepRange.splitTo2Integer()?.0 ?? field.hour
            let dtSeconds = field.stepType == "instant" ? domain.dtSeconds : max(1, field.hour - start) * 3600
            if field.stepType == "accum" || field.stepType == "avg" {
                if field.hour == 0 {
                    field.array2d.data = [Float](repeating: .nan, count: field.array2d.data.count)
                } else {
                    let accumulated = AccumulatedVariable(variable: field.variable, shortName: field.shortName, stepType: field.stepType, stepRange: field.stepRange)
                    await inMemoryAccumulated.set(variable: accumulated, timestamp: run.add(hours: field.hour), member: field.member, data: field.array2d)
                    // Drain buffered timesteps in sequence. Each result keeps its own timestamp.
                    while true {
                        try Task.checkCancellation()
                        let processStart = DispatchTime.now()
                        let lastStep = await deaverager.lastStep(field.variable, field.member) ?? 0
                        guard let step = nextHours[lastStep] else { break }
                        let timestamp = run.add(hours: step)
                        guard let next = await inMemoryAccumulated.remove(timestamp: timestamp, member: field.member, matching: { $0.variable == field.variable }) else { break }
                        let metadata = next.variable
                        var data = next.data
                        var stepRange = metadata.stepRange
                        if metadata.stepType == "accum" && !stepRange.contains("-") { stepRange = "0-\(stepRange)" }
                        if domain == .aifs025_single && metadata.stepType == "accum" { stepRange = "0-\(step)" }
                        guard let (start, end) = stepRange.splitTo2Integer(), start < end, end == step else {
                            throw EcmwfLocalGribFile.Failure.invalidMetadata
                        }
                        guard await deaverager.deaccumulateIfRequired(variable: metadata.variable, member: field.member, stepType: metadata.stepType, startStep: start, currentStep: step, array2d: &data) else { continue }
                        if step == lastHour { await deaverager.remove(variable: metadata.variable, member: field.member) }
                        let dtSeconds = (step - max(start, lastStep)) * 3600
                        if let fma = metadata.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                            data.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        let processTime = processStart.timeElapsedSeconds()
                        decoded.append((metadata.variable, field.member, step, data.data, processTime))
                    }
                    await progress.add(entry.field.range.count)
                    return decoded
                }
            }
            if field.stepType != "instant" {
                if field.shortName == "z" { field.array2d.data.multiplyAdd(multiply: 1 / 9.80665, add: 0) }
                if let fma = field.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                    field.array2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
            }
            let timestamp = run.add(hours: field.hour)
            var results = [(variable: EcmwfVariable, data: [Float])]()
            let parameter = field.variable.gribName
            switch parameter {
            case "2t", "2d":
                guard field.stepType == "instant" else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                let input: RelativeHumidityCalculator.Input = parameter == "2t" ? .temperature(field.array2d) : .dewpoint(field.array2d)
                if let data = await rhCalculator.calculate(input, member: field.member, timestamp: timestamp) {
                    results.append((.relative_humidity_2m, data))
                }
            case "sd", "rsn":
                if !isAifs {
                    guard field.stepType == "instant" else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                    let input: SnowDepthCalculator.Input = parameter == "sd" ? .waterEquivalent(field.array2d) : .density(field.array2d)
                    if let data = await snowDepthCalculator.calculate(input, member: field.member, timestamp: timestamp) {
                        results.append((.snow_depth, data))
                    }
                }
            case "t", "w", "q":
                let level = field.variable.level!
                if parameter != "q", let output = EcmwfVariable.from(shortName: "w", levelhPa: level) {
                    guard field.stepType == "instant" else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                    let input: VerticalVelocityCalculator<EcmwfVariable>.Input = parameter == "t" ? .temperature(field.array2d) : .omega(field.array2d)
                    if let data = await verticalVelocityCalculator.calculate(input, member: field.member, timestamp: timestamp, pressureLevel: Float(level), outVariable: output) {
                        results.append((output, data))
                    }
                }
                if isAifs && level != 10 && parameter != "w", let output = EcmwfVariable.from(shortName: "r", levelhPa: level) {
                    guard field.stepType == "instant" else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                    let input: SpecificHumidityCalculator<EcmwfVariable>.Input = parameter == "t" ? .temperature(field.array2d) : .specificHumidity(field.array2d)
                    if let data = await specificHumidityCalculator.calculate(input, member: field.member, timestamp: timestamp, pressureLevel: Float(level), outVariable: output) {
                        results.append((output, data))
                    }
                }
            default:
                break
            }
            // Derived inputs are never written as if they were the final output.
            if !["2d", "rsn", "w", "q"].contains(parameter) {
                results.append((field.variable, field.array2d.data))
            }
            let processTime = processStart.timeElapsedSeconds() / Double(max(1, results.count))
            for result in results {
                decoded.append((result.variable, field.member, field.hour, result.data, processTime))
            }
            await progress.add(entry.field.range.count)
            return decoded
        })
        for try await field in processed.flatMap({ $0.async }) {
            let variable = field.variable
            let key = EnsembleVariableMember(variable: variable, member: field.member)
            var current = series.removeValue(forKey: key) ?? ([], 0)
            current.timesteps.append((time: field.hour * 3600 / domain.dtSeconds, data: field.data))
            current.process += field.process
            // A worker can drain several accumulated steps, so ordered input
            // tasks do not guarantee ordered output hours (or member completion).
            let expectedSteps = hours.count - (variable.skipHourZero && hours.first == 0 ? 1 : 0)
            guard current.timesteps.count == expectedSteps else {
                series[key] = current
                continue
            }

            let transposeStart = DispatchTime.now()
            var data = await Array2DFastTime(timesteps: current.timesteps, nLocations: domain.grid.count, nTime: time.count, nConcurrent: concurrent)
            current.timesteps.removeAll()
            let transposeTime = transposeStart.timeElapsedPretty()
            let interpolationStart = DispatchTime.now()
            await data.interpolateInplace(type: variable.interpolation, time: time, grid: domain.grid, locationRange: 0..<domain.grid.count, nConcurrent: concurrent)
            let interpolationTime = interpolationStart.timeElapsedPretty()
            let writeStart = DispatchTime.now()
            let writer = OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx, time.count], chunks: [chunks.y, chunks.x, time.count])
            let fn = try await writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: data.data, nConcurrent: concurrent)
            let handle = try await GenericVariableHandle(variable: variable, time: run, member: field.member, fn: fn, domain: domain)
            data = Array2DFastTime(nLocations: domain.grid.count, nTime: 0)
            logger.info("\(variable.rawValue) member \(field.member): process=\(current.process.asSecondsPrettyPrint), transpose=\(transposeTime), interpolation=\(interpolationTime), write=\(writeStart.timeElapsedPretty())")
            handles[variable, default: []].append(handle)
            guard handles[variable]!.count == domain.countEnsembleMember else { continue }

            let completedHandles = handles.removeValue(forKey: variable)!
            let conversionWaitStart = DispatchTime.now()
            try await conversionJob?.value
            logger.info("Before converting \(variable.rawValue): conversionWait=\(conversionWaitStart.timeElapsedPretty())")
            conversionJob = Task {
                let conversionStart = DispatchTime.now()
                try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: completedHandles, concurrent: 1, spatialConcurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: domain.countEnsembleMember == 1, generateTimeSeries: generateTimeSeries, ensembleMeanDomain: domain.ensembleMeanDomain, precipitationProbability: true)
                logger.info("Convert \(variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
            }
        }
        let remainingHistory = await deaverager.data.count
        let remainingAccumulated = await inMemoryAccumulated.data.count
        guard series.isEmpty, handles.isEmpty, remainingHistory == 0, remainingAccumulated == 0 else {
            for (key, pending) in series {
                let receivedHours = pending.timesteps.map { $0.time * domain.dtSeconds / 3600 }.sorted()
                logger.error("Incomplete time series: \(key.variable.rawValue) member \(key.member), received hours \(receivedHours)")
            }
            for (variable, pending) in handles {
                logger.error("Incomplete members: \(variable.rawValue), completed members \(pending.map(\.member).sorted())")
            }
            logger.error("Unfinished ensemble conversion: series=\(series.count), variables=\(handles.count), deaverager=\(remainingHistory), accumulated=\(remainingAccumulated)")
            throw EcmwfLocalGribFile.Failure.invalidMetadata
        }
        await progress.finish()
        let conversionWaitStart = DispatchTime.now()
        try await conversionJob?.value
        logger.info("Final conversionWait=\(conversionWaitStart.timeElapsedPretty())")
        try await publishLocalGribRun(signature: signature, domain: domain, run: run, time: time, uploadQueues: uploadQueues)
        await curl.printStatistics()
    }

    private func downloadLocalGribFiles(curl: Curl, domain: EcmwfDomain, base: String, run: Timestamp, hours: [Int], concurrent: Int, downloadConcurrent: Int) async throws -> [(hour: Int, file: EcmwfLocalGribFile)] {
        let files = hours.flatMap { hour in domain.getUrl(base: base, run: run, hour: hour).map { (hour: hour, url: $0) } }
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let downloads = files.map { (url: $0.url, path: domain.downloadDirectory + URL(string: $0.url)!.lastPathComponent) }
        let hoursByURL = Dictionary(uniqueKeysWithValues: files.map { ($0.url, $0.hour) })
        curl.logger.info("Scanning GRIB headers as files become available")
        return try await curl.downloadChunked(files: downloads, nConcurrent: downloadConcurrent, deadLineHours: 5.5)
            .mapConcurrent(nConcurrent: concurrent) { file in
                (hour: hoursByURL[file.url]!, file: try EcmwfLocalGribFile(handle: file.handle, source: file.url))
            }
    }

    private func publishLocalGribRun(signature: Signature, domain: EcmwfDomain, run: Timestamp, time: TimerangeDt, uploadQueues: [S3UploadQueue]) async throws {
        // Publish the run only after all available variables have been converted.
        if !signature.skipTimeseries && signature.timeinterval == nil && domain.generateTimeSeries {
            for outputDomain in [domain, domain.ensembleMeanDomain].compactMap({ $0 }) {
                let data = try ModelUpdateMetaJson.update(domain: outputDomain, run: run, end: time.range.upperBound, now: .now())
                for queue in uploadQueues {
                    await queue.upload(data: data, objectName: "data/\(outputDomain.domainRegistry.rawValue)/static/meta.json", contentType: "application/json", lastModified: .now())
                }
            }
        }
    }

    func downloadWaveVariables(application: Application, signature: Signature, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfWaveVariable], concurrent: Int, downloadConcurrent: Int, uploadQueues: [S3UploadQueue]) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5, chunkSizeMB: EcmwfOpenDataSource.fullFileChunkSizeMB(base: base), retryUnauthorized: true, prepareRequest: EcmwfAzureAccess.prepareRequest(base: base, client: application.dedicatedHttpClient))
        let hours = domain.getDownloadForecastSteps(run: run.hour).filter { $0 <= (signature.maxForecastHour ?? Int.max) }
        guard let lastHour = hours.last else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let inventories = try await downloadLocalGribFiles(curl: curl, domain: domain, base: base, run: run, hours: hours, concurrent: concurrent, downloadConcurrent: downloadConcurrent)
        let chunks = OmFileSplitter(domain).spatialReadChunkDimensions
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        var conversionJob: Task<Void, any Error>?
        defer { conversionJob?.cancel() }
        var convertedVariables = 0
        for variable in variables {
            let fields = inventories.flatMap { inventory in
                inventory.file.fields.filter { $0.shortName == variable.gribName }.map {
                    (hour: inventory.hour, file: inventory.file, field: $0)
                }
            }.sorted { ($0.field.member, $0.hour) < ($1.field.member, $1.hour) }
            guard !fields.isEmpty else { continue }
            var hoursPerMember = [Set<Int>](repeating: [], count: domain.countEnsembleMember)
            for entry in fields {
                guard hoursPerMember.indices.contains(entry.field.member), hoursPerMember[entry.field.member].insert(entry.hour).inserted else {
                    throw EcmwfLocalGribFile.Failure.invalidMetadata
                }
            }
            guard hoursPerMember.allSatisfy({ $0 == Set(hours) }) else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
            logger.info("Reading \(variable.rawValue): \(fields.count) local fields")
            var timesteps = [(time: Int, data: [Float])]()
            var handles = [GenericVariableHandle]()
            var decodeTime = 0.0
            let processed = fields.mapStream(nConcurrent: concurrent) { entry in
                let decodeStart = DispatchTime.now()
                let data = try entry.file.withMessage(field: entry.field) { message in
                    var grib = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    try grib.load(message: message)
                    grib.array.flipLatitude()
                    return grib.array.data
                }
                return (hour: entry.hour, member: entry.field.member, data: data, decode: decodeStart.timeElapsedSeconds())
            }
            for try await field in processed {
                timesteps.append((time: field.hour * 3600 / domain.dtSeconds, data: field.data))
                decodeTime += field.decode
                guard field.hour == lastHour else { continue }

                let transposeStart = DispatchTime.now()
                var data = await Array2DFastTime(timesteps: timesteps, nLocations: domain.grid.count, nTime: time.count, nConcurrent: concurrent)
                timesteps.removeAll()
                let transposeTime = transposeStart.timeElapsedPretty()
                let interpolationStart = DispatchTime.now()
                await data.interpolateInplace(type: variable.interpolation, time: time, grid: domain.grid, locationRange: 0..<domain.grid.count, nConcurrent: concurrent)
                let interpolationTime = interpolationStart.timeElapsedPretty()
                let writeStart = DispatchTime.now()
                let writer = OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx, time.count], chunks: [chunks.y, chunks.x, time.count])
                let fn = try await writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: data.data, nConcurrent: concurrent)
                handles.append(try await GenericVariableHandle(variable: variable, time: run, member: field.member, fn: fn, domain: domain))
                logger.info("\(variable.rawValue) member \(field.member): decode=\(decodeTime.asSecondsPrettyPrint), transpose=\(transposeTime), interpolation=\(interpolationTime), write=\(writeStart.timeElapsedPretty())")
                decodeTime = 0
            }
            let conversionWaitStart = DispatchTime.now()
            try await conversionJob?.value
            logger.info("Before converting \(variable.rawValue): conversionWait=\(conversionWaitStart.timeElapsedPretty())")
            let completedHandles = handles
            conversionJob = Task {
                let conversionStart = DispatchTime.now()
                try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: completedHandles, concurrent: 1, spatialConcurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: !domain.isEnsemble, generateTimeSeries: !signature.skipTimeseries, ensembleMeanDomain: domain.ensembleMeanDomain)
                logger.info("Convert \(variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
            }
            convertedVariables += 1
        }
        guard convertedVariables > 0 else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let conversionWaitStart = DispatchTime.now()
        try await conversionJob?.value
        logger.info("Final conversionWait=\(conversionWaitStart.timeElapsedPretty())")
        try await publishLocalGribRun(signature: signature, domain: domain, run: run, time: time, uploadQueues: uploadQueues)
        await curl.printStatistics()
    }
}
