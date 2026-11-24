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
        let inventories = try await curl.downloadChunked(files: downloads, nConcurrent: downloadConcurrent, deadLineHours: 5.5)
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
        // Convert each variable once all its spatial fields have been written.
        var conversionJob: Task<Void, any Error>?

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: fields.reduce(0) { $0 + $1.field.range.count }, name: "Read \(domain.rawValue)")
        let lastMember = domain.countEnsembleMember - 1
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        guard !fields.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        let isAifs = domain == .aifs025_single || domain == .aifs025_ensemble || domain == .aifs025_ensemble_mean
        let snowDepthCalculator = SnowDepthCalculator()
        let verticalVelocityCalculator = VerticalVelocityCalculator<EcmwfVariable>()
        let specificHumidityCalculator = SpecificHumidityCalculator<EcmwfVariable>()
        let rhCalculator = RelativeHumidityCalculator(outVariable: EcmwfVariable.relative_humidity_2m)
        let chunks = OmFileSplitter(domain).spatialReadChunkDimensions
        // Writers create timestep files lazily, including outputs produced by calculators.
        let writers = Dictionary(uniqueKeysWithValues: EcmwfVariable.allCases.map { variable in
            (variable, OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: logger, chunkDimensions: [chunks.y, chunks.x]))
        })
        let deaverager = GribDeaverager()
        let inMemoryAccumulated = VariablePerMemberStorage<AccumulatedVariable>()
        let positiveHours = hours.filter { $0 > 0 }
        let nextHours = Dictionary(uniqueKeysWithValues: zip([0] + positiveHours, positiveHours))
        var timings = [EcmwfVariable: (process: Double, write: Double)]()
        defer { conversionJob?.cancel() }

        // Workers decode, deaccumulate, derive and write spatial fields. Only
        // completed-field accounting and conversion scheduling run in the consumer.
        let processed = fields.mapStream(nConcurrent: concurrent, nBuffered: concurrent, body: { entry -> [(variable: EcmwfVariable, member: Int, hour: Int, process: Double, write: Double)] in
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
            var written = [(variable: EcmwfVariable, member: Int, hour: Int, process: Double, write: Double)]()
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
                        let writeStart = DispatchTime.now()
                        try await writers[metadata.variable]!.write(time: timestamp, member: field.member, variable: metadata.variable, data: data.data)
                        written.append((metadata.variable, field.member, step, processTime, writeStart.timeElapsedSeconds()))
                    }
                    await progress.add(entry.field.range.count)
                    return written
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
                let writer = writers[result.variable]!
                let writeStart = DispatchTime.now()
                try await writer.write(time: timestamp, member: field.member, variable: result.variable, data: result.data)
                written.append((result.variable, field.member, field.hour, processTime, writeStart.timeElapsedSeconds()))
            }
            await progress.add(entry.field.range.count)
            return written
        })
        for try await field in processed.flatMap({ $0.async }) {
            let variable = field.variable
            var timing = timings.removeValue(forKey: variable) ?? (0, 0)
            timing.process += field.process
            timing.write += field.write
            guard field.hour == lastHour else {
                timings[variable] = timing
                continue
            }
            logger.info("\(variable.rawValue) member \(field.member): process=\(timing.process.asSecondsPrettyPrint), write=\(timing.write.asSecondsPrettyPrint)")
            guard field.member == lastMember else { continue }

            let handles = try await writers[variable]!.finalise()
            let conversionWaitStart = DispatchTime.now()
            try await conversionJob?.value
            logger.info("Before converting \(variable.rawValue): conversionWait=\(conversionWaitStart.timeElapsedPretty())")
            conversionJob = Task {
                let conversionStart = DispatchTime.now()
                try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: 1, spatialConcurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: domain.countEnsembleMember == 1, generateTimeSeries: generateTimeSeries, ensembleMeanDomain: domain.ensembleMeanDomain, precipitationProbability: true)
                logger.info("Convert \(variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
            }
        }
        guard timings.isEmpty, await deaverager.data.isEmpty, await inMemoryAccumulated.data.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        await progress.finish()
        let conversionWaitStart = DispatchTime.now()
        try await conversionJob?.value
        logger.info("Final conversionWait=\(conversionWaitStart.timeElapsedPretty())")
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
