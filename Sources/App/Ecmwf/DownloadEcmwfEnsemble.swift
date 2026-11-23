import AsyncAlgorithms
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
        let unitsConverted: Bool
        let hour: Int
        let member: Int
        let shortName: String
        let stepType: String
        let stepRange: String
        var grib: GribArray2D
    }

    struct EnsembleAccumulation: Hashable, Sendable {
        let variable: EcmwfVariable
        let shortName: String
        let stepType: String
        let stepRange: String
    }

    struct EnsembleVariableMember: Hashable {
        let variable: EcmwfVariable
        let member: Int
    }

    /// Cache complete GRIB files, scan their headers, then read time series locally.
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
        let elevationURL = domain.elevationDomain.getUrl(base: base, run: run, hour: 0)[0]
        let elevationPath = domain.downloadDirectory + URL(string: elevationURL)!.lastPathComponent
        let needsElevation = !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath())
        let localFiles = files.map { (hour: $0.hour, path: domain.downloadDirectory + URL(string: $0.url)!.lastPathComponent) }
        var downloads = zip(files, localFiles).map { (url: $0.0.url, path: $0.1.path) }
        // Pressure-level downloads need one additional surface control file at hour zero.
        if needsElevation && !files.contains(where: { $0.url == elevationURL }) {
            downloads.insert((url: elevationURL, path: elevationPath), at: 0)
        }
        let hoursByPath = Dictionary(uniqueKeysWithValues: localFiles.map { ($0.path, $0.hour) })
        logger.info("Scanning GRIB headers as files become available")
        let inventories = try await curl.download(files: downloads, nConcurrent: downloadConcurrent, deadLineHours: 5.5)
            .mapConcurrent(nConcurrent: concurrent) { file -> (hour: Int, file: EcmwfLocalGribFile)? in
                // The additional surface file is only needed for elevation.
                guard let hour = hoursByPath[file.path] else { return nil }
                return (hour: hour, file: try EcmwfLocalGribFile(path: file.path))
            }.compactMap { $0 }
        // Elevation must also use a complete local file, never an index inventory.
        if needsElevation {
            try await downloadEcmwfElevation(application: application, domain: domain, base: base, run: run, uploadQueues: uploadQueues, localGribPath: elevationPath)
        }

        let createNetcdf = signature.createNetcdf
        let generateTimeSeries = !signature.skipTimeseries
        // Keep related inputs adjacent, but derivation only depends on cache
        // availability, not on this ordering or any explicit download groups.
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
            // Finish related inputs together, keeping their spatial cache bounded.
            // There are no boundaries or derivation triggers in this order.
            if (a.0, a.1) != (b.0, b.1) { return (a.0, a.1) < (b.0, b.1) }
            if $0.member != $1.member { return $0.member < $1.member }
            if $0.variable != $1.variable { return a < b }
            if $0.hour != $1.hour { return $0.hour < $1.hour }
            return $0.field.range.lowerBound < $1.field.range.lowerBound
        }
        logger.info("Reading \(availableVariables.count) variables: \(fields.count) local fields")
        // Temporary handles avoid rereading the whole rolling file for each member.
        var conversionJob: Task<Void, any Error>?

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: fields.reduce(0) { $0 + $1.field.range.count }, name: "Read \(domain.rawValue)")
        let nMembers = domain.countEnsembleMember
        let chunkLocations = min(domain.grid.nx, OmFileSplitter(domain, nMembers: nMembers).chunknLocations)
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        var handles = [GenericVariableHandle]()
        var writeJob: Task<GenericVariableHandle, any Error>? = nil
        guard !fields.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        let time = TimerangeDt(start: run, nTime: lastHour * 3600 / domain.dtSeconds + 1, dtSeconds: domain.dtSeconds)
        let isAifs = domain == .aifs025_single || domain == .aifs025_ensemble || domain == .aifs025_ensemble_mean
        let inputs = Set(availableVariables.map(\.gribKey))
        // Instantaneous derived fields share their decoded spatial input. Each
        // complete source time series is ordered before its consumers, with
        // temperature first and omega/q or dewpoint immediately afterwards.
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
        var derivations = [EcmwfVariable: [(consumer: EcmwfVariable, source: EcmwfVariable)]]()
        for (consumer, source) in dependencies {
            derivations[source, default: []].append((consumer, source))
            derivations[consumer, default: []].append((consumer, source))
        }
        let sourceVariables = derivations
        let decodedOutputs = outputVariables
        let spatialInputs = VariablePerMemberStorage<String>()
        let expectedHours = Dictionary(outputVariables.map { input, output in
            (output, hours.count - (input.skipHourZero && hours.first == 0 ? 1 : 0))
        }, uniquingKeysWith: { first, _ in first })
        let positiveHours = hours.filter { $0 > 0 }
        let nextHour = Dictionary(uniqueKeysWithValues: zip([0] + positiveHours, positiveHours))
        let lastMember = nMembers - 1
        // Completed jobs may emit multiple variables, with derived hours arriving
        // late. Keep independent time-fast buffers and finish by received count.
        var series = [EnsembleVariableMember: (data: Array2DFastTime, count: Int, activeTime: Double, start: DispatchTime)]()
        let inMemoryAccumulated = VariablePerMemberStorage<EnsembleAccumulation>()
        let deaverager = GribDeaverager()

        // One ordered local stream reads timesteps in parallel and keeps related
        // variable/member inputs adjacent for derivation and time-series assembly.
        let decoded = fields.mapStream(nConcurrent: concurrent, nBuffered: 2 * concurrent, body: { entry -> [DecodedEnsembleField] in
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
                return DecodedEnsembleField(variable: entry.variable, unitsConverted: stepType == "instant", hour: entry.hour, member: entry.member, shortName: shortName, stepType: stepType, stepRange: stepRange, grib: grib)
            }
            await progress.add(entry.field.range.count)
            if field.stepType == "accum" || field.stepType == "avg" {
                // Hour zero has no preceding interval. Preserve its NaN column,
                // while starting the sequential drain at the first forecast step.
                if field.hour == 0 {
                    field.grib.array.data = [Float](repeating: .nan, count: field.grib.array.data.count)
                    return [field]
                }
                var stepRange = field.stepRange
                if field.stepType == "accum" && !stepRange.contains("-") { stepRange = "0-\(stepRange)" }
                if domain == .aifs025_single && field.stepType == "accum" { stepRange = "0-\(field.hour)" }
                let metadata = EnsembleAccumulation(variable: entry.variable, shortName: field.shortName, stepType: field.stepType, stepRange: stepRange)
                await inMemoryAccumulated.set(variable: metadata, timestamp: run.add(hours: field.hour), member: field.member, data: field.grib.array)
                var result = [DecodedEnsembleField]()
                while true {
                    let previousStep = await deaverager.lastStep(entry.variable, entry.member)
                    // Use the actual forecast steps, including the 3h -> 6h transition.
                    guard let step = nextHour[previousStep ?? 0] else { break }
                    let timestamp = run.add(hours: step)
                    guard let buffered = await inMemoryAccumulated.remove(where: {
                        $0.variable.variable == entry.variable && $0.timestamp == timestamp && $0.member == entry.member
                    }) else { break }
                    let metadata = buffered.key.variable
                    guard let (start, end) = metadata.stepRange.splitTo2Integer(), start < end, end == step else {
                        throw EcmwfLocalGribFile.Failure.invalidMetadata
                    }
                    var values = buffered.data
                    guard await deaverager.deaccumulateIfRequired(variable: entry.variable, member: entry.member, stepType: metadata.stepType, startStep: start, currentStep: end, array2d: &values) else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                    let dtSeconds = max(1, step - max(start, previousStep ?? start)) * 3600
                    if metadata.shortName == "z" { await values.data.multiplyAddConcurrent(multiply: 1 / 9.80665, add: 0) }
                    if let fma = entry.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                        await values.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                    }
                    var grib = field.grib
                    grib.array = values
                    result.append(DecodedEnsembleField(variable: entry.variable, unitsConverted: true, hour: step, member: entry.member, shortName: metadata.shortName, stepType: metadata.stepType, stepRange: metadata.stepRange, grib: grib))
                    if step == lastHour {
                        await deaverager.remove(variable: entry.variable, member: entry.member)
                        break
                    }
                }
                return result
            }
            if !field.unitsConverted {
                // Max/min and other non-accumulated fields still need unit conversion.
                let start = field.stepRange.splitTo2Integer()?.0 ?? field.hour
                let dtSeconds = max(1, field.hour - start) * 3600
                if field.shortName == "z" { await field.grib.array.data.multiplyAddConcurrent(multiply: 1 / 9.80665, add: 0) }
                if let fma = entry.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                    await field.grib.array.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                }
            }
            let timestamp = run.add(hours: entry.hour)
            var result = [DecodedEnsembleField]()
            // Separate source keys per consumer let omega and q share the same
            // temperature array without either removing the other's input.
            for (consumer, source) in sourceVariables[entry.variable] ?? [] {
                guard field.unitsConverted else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                let sourceKey = "\(source.gribKey)>\(consumer.gribKey)"
                let key = entry.variable == source ? sourceKey : consumer.gribKey
                await spatialInputs.set(variable: key, timestamp: timestamp, member: entry.member, data: field.grib.array)
                guard let pair = await spatialInputs.getAllRemoving(variables: [sourceKey, consumer.gribKey], timestamp: timestamp, member: entry.member) else { continue }
                var grib = field.grib
                switch consumer.gribName {
                case "2d":
                    grib.array.data = zip(pair[0].data, pair[1].data).map(Meteorology.relativeHumidity)
                case "rsn":
                    grib.array.data = zip(pair[0].data, pair[1].data).map(/)
                case "w":
                    grib.array.data = Meteorology.verticalVelocityPressureToGeometric(omega: pair[1].data, temperature: pair[0].data, pressureLevel: Float(consumer.level!))
                case "q":
                    grib.array.data = Meteorology.specificToRelativeHumidity(specificHumidity: pair[1].data, temperature: pair[0].data, pressure: Float(consumer.level!))
                default: continue
                }
                result.append(DecodedEnsembleField(variable: decodedOutputs[consumer]!, unitsConverted: true, hour: entry.hour, member: entry.member, shortName: consumer.gribName!, stepType: "instant", stepRange: field.stepRange, grib: grib))
            }
            if !["2d", "rsn", "w", "q"].contains(entry.variable.gribName) {
                result.append(field)
            }
            return result
        })
        for try await decodedField in decoded.flatMap({ $0.async }) {
            let member = decodedField.member
            let variable = decodedField.variable
            let key = EnsembleVariableMember(variable: variable, member: member)
            var current = series.removeValue(forKey: key) ?? (Array2DFastTime(nLocations: domain.grid.count, nTime: time.count), 0, 0, DispatchTime.now())
            let loopStart = DispatchTime.now()
            await current.data.setConcurrent(location: 0..<domain.grid.count, time: decodedField.hour * 3600 / domain.dtSeconds, values: decodedField.grib.array.data)
            current.activeTime += loopStart.timeElapsedSeconds()
            current.count += 1
            guard current.count == expectedHours[variable]! else {
                series[key] = current
                continue
            }
            var data = current.data
            current.data = Array2DFastTime(nLocations: domain.grid.count, nTime: 0)
            let readTime = current.start.timeElapsedPretty()
            let interpolationStart = DispatchTime.now()
            await data.interpolateInplace(type: variable.interpolation, time: time, grid: domain.grid, locationRange: 0..<domain.grid.count, nConcurrent: concurrent)
            let interpolationTime = interpolationStart.timeElapsedPretty()
            let convertLoopTime = current.activeTime.asSecondsPrettyPrint
            let waitStart = DispatchTime.now()
            if let writeJob { handles.append(try await writeJob.value) }
            let writeJobWait = waitStart.timeElapsedPretty()
            let values = data.data
            data = Array2DFastTime(nLocations: domain.grid.count, nTime: 0)
            writeJob = Task {
                let writeStart = DispatchTime.now()
                let writer = OmFileWriterHelper(dimensions: [domain.grid.ny, domain.grid.nx, time.count], chunks: [1, chunkLocations, time.count])
                let fn = try await writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: values, nConcurrent: concurrent)
                let handle = try await GenericVariableHandle(variable: variable, time: run, member: member, fn: fn, domain: domain)
                logger.info("\(variable.rawValue) member \(member): write=\(writeStart.timeElapsedPretty()), interpolation=\(interpolationTime), wait=\(writeJobWait), read=\(readTime), transpose=\(convertLoopTime)")
                return handle
            }
            // Convert an output once its final member has been written.
            if member == lastMember {
                let waitStart = DispatchTime.now()
                if let writeJob {
                    handles.append(try await writeJob.value)
                }
                writeJob = nil
                logger.info("\(variable.rawValue) final write wait=\(waitStart.timeElapsedPretty())")
                let completedHandles = handles.filter { $0.variable.rawValue == variable.rawValue }
                handles.removeAll { $0.variable.rawValue == variable.rawValue }
                try await conversionJob?.value
                conversionJob = Task {
                    let handles = completedHandles
                    guard let first = handles.first else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
                    let conversionStart = DispatchTime.now()
                    try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: 1, spatialConcurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: domain.countEnsembleMember == 1, generateTimeSeries: generateTimeSeries, ensembleMeanDomain: domain.ensembleMeanDomain, precipitationProbability: true)
                    logger.info("Convert \(first.variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
                }
            }
        }
        guard series.isEmpty, await inMemoryAccumulated.data.isEmpty, await spatialInputs.data.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
        await progress.finish()
        if let writeJob { handles.append(try await writeJob.value) }
        try await conversionJob?.value
        guard handles.isEmpty else { throw EcmwfLocalGribFile.Failure.invalidMetadata }
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
