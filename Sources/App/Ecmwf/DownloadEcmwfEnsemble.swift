import AsyncAlgorithms
import Foundation
import NIOCore
import OmFileIO
import Vapor

extension DownloadEcmwfCommand {
    struct EnsembleInventory: Sendable {
        let hour: Int
        let url: String
        let entries: [Curl.EcmwfIndexEntry]
    }

    struct EnsembleDownload: Sendable {
        let variable: EcmwfVariable
        let hour: Int
        let member: Int
        let url: String
        let range: Range<Int>
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

    /// Fetch inventories once, then overlap bounded variable downloads with writing and conversion.
    func downloadEnsembleVariables(application: Application, signature: Signature, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfVariable], concurrent: Int, downloadConcurrent: Int, uploadQueues: [S3UploadQueue]) async throws {
        guard !variables.isEmpty else { throw CurlError.didNotFindAllVariablesInGribIndex }
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5, retryUnauthorized: true, prepareRequest: EcmwfAzureAccess.prepareRequest(base: base, client: application.dedicatedHttpClient))
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        let hours = domain.getDownloadForecastSteps(run: run.hour).filter { $0 <= (signature.maxForecastHour ?? Int.max) }
        guard let lastHour = hours.last else { throw CurlError.didNotFindAllVariablesInGribIndex }
        let files = hours.flatMap { hour in domain.getUrl(base: base, run: run, hour: hour).map { (hour: hour, url: $0) } }
        var inventories = [EnsembleInventory]()
        for try await inventory in files.mapStream(nConcurrent: downloadConcurrent, nBuffered: 2 * downloadConcurrent, body: { file in
            let request = try EcmwfOpenDataSource.prepareDownload(url: file.url)
            let entries = try await curl.downloadInMemoryAsync(url: request.indexURL, minSize: nil, quiet: true).readEcmwfIndexEntries()
            return EnsembleInventory(hour: file.hour, url: request.url, entries: entries)
        }) {
            inventories.append(inventory)
        }

        let allInventories = inventories
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
        var downloads = [EnsembleDownload]()
        var availableVariables = [EcmwfVariable]()
        for variable in variables {
            var fieldsPerMember = [Int](repeating: 0, count: domain.countEnsembleMember)
            for inventory in allInventories {
                if inventory.hour == 0 && variable.skipHourZero { continue }
                let entries = inventory.entries.filter(variable.matches)
                for entry in entries {
                    if entry.param != variable.gribName && entries.contains(where: { $0.param == variable.gribName && $0.number == entry.number }) { continue }
                    guard let member = Int(entry.number ?? "0"), (0..<domain.countEnsembleMember).contains(member),
                          entry._offset >= 0, entry._length > 0, entry._offset <= Int.max - entry._length else {
                        throw CurlMemoryDownloadError.invalidRangeResponse
                    }
                    downloads.append(EnsembleDownload(variable: variable, hour: inventory.hour, member: member, url: inventory.url, range: entry._offset..<entry._offset + entry._length))
                    fieldsPerMember[member] += 1
                }
            }
            // Skip parameters this model does not supply, but require all forecast
            // steps for every member of each available variable.
            guard fieldsPerMember.contains(where: { $0 > 0 }) else { continue }
            let expectedCount = hours.count - (variable.skipHourZero && hours.first == 0 ? 1 : 0)
            for (member, count) in fieldsPerMember.enumerated() where count != expectedCount {
                logger.error("Incomplete GRIB index: \(variable.rawValue) member \(member) has \(count) fields, expected \(expectedCount)")
                throw CurlError.didNotFindAllVariablesInGribIndex
            }
            availableVariables.append(variable)
        }
        downloads.sort {
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
            return $0.range.lowerBound < $1.range.lowerBound
        }
        logger.info("Downloading \(availableVariables.count) variables: \(downloads.count) fields")
        // Temporary handles avoid rereading the whole rolling file for each member.
        var conversionJob: Task<Void, any Error>?

        let progress = TransferAmountTracker(logger: curl.logger, totalSize: downloads.reduce(0) { $0 + $1.range.count }, name: "Download \(domain.rawValue)")
        let nMembers = domain.countEnsembleMember
        let chunkLocations = min(domain.grid.nx, OmFileSplitter(domain, nMembers: nMembers).chunknLocations)
        try FileManager.default.createDirectory(atPath: OpenMeteo.tempDirectory, withIntermediateDirectories: true)
        var handles = [GenericVariableHandle]()
        var writeJob: Task<GenericVariableHandle, any Error>? = nil
        guard !downloads.isEmpty else { throw CurlError.didNotFindAllVariablesInGribIndex }
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

        // Keep one ordered stream alive so downloads can cross member boundaries.
        let decoded = downloads.mapStream(nConcurrent: downloadConcurrent, nBuffered: 2 * downloadConcurrent, body: { download -> [DecodedEnsembleField] in
            let range = "\(download.range.lowerBound)-\(download.range.upperBound - 1)"
            let buffer = try await curl.downloadInMemoryAsync(url: download.url, range: range, minSize: download.range.count, cacheDirectory: nil, quiet: true)
            await progress.add(buffer.readableBytes)
            // Decode while the compressed buffer is alive; only owned arrays leave this job.
            var field = try buffer.withUnsafeReadableBytes { bytes in
                guard let message = try GribAsyncStreamHelper.decodeMessages(memory: bytes).first else {
                    throw GribAsyncStreamError.didNotFindGibHeader
                }
                guard let shortName = message.get(attribute: "shortName"),
                      let level = message.get(attribute: "level").flatMap(Int.init),
                      let stepType = message.get(attribute: "stepType"),
                      let stepRange = message.get(attribute: "stepRange") else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                guard download.variable.matches(shortName: shortName, level: level) else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                guard (message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0) == download.member else {
                    throw CurlMemoryDownloadError.invalidRangeResponse
                }
                var grib = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib.load(message: message)
                grib.array.flipLatitude()
                // These inputs are instantaneous. Convert units before sharing
                // them, so RH uses Celsius and specific humidity uses g/kg.
                if stepType == "instant" {
                    if shortName == "z" { grib.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0) }
                    let fma = download.variable.gribName == "2d" ? (multiply: Float(1), add: Float(-273.15)) : download.variable.multiplyAdd(domain: domain, dtSeconds: domain.dtSeconds)
                    if let fma { grib.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add) }
                }
                return DecodedEnsembleField(variable: download.variable, unitsConverted: stepType == "instant", hour: download.hour, member: download.member, shortName: shortName, stepType: stepType, stepRange: stepRange, grib: grib)
            }
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
                let metadata = EnsembleAccumulation(variable: download.variable, shortName: field.shortName, stepType: field.stepType, stepRange: stepRange)
                await inMemoryAccumulated.set(variable: metadata, timestamp: run.add(hours: field.hour), member: field.member, data: field.grib.array)
                var result = [DecodedEnsembleField]()
                while true {
                    let previousStep = await deaverager.lastStep(download.variable, download.member)
                    // Use the actual forecast steps, including the 3h -> 6h transition.
                    guard let step = nextHour[previousStep ?? 0] else { break }
                    let timestamp = run.add(hours: step)
                    guard let buffered = await inMemoryAccumulated.remove(where: {
                        $0.variable.variable == download.variable && $0.timestamp == timestamp && $0.member == download.member
                    }) else { break }
                    let metadata = buffered.key.variable
                    guard let (start, end) = metadata.stepRange.splitTo2Integer(), start < end, end == step else {
                        throw CurlMemoryDownloadError.invalidRangeResponse
                    }
                    var values = buffered.data
                    guard await deaverager.deaccumulateIfRequired(variable: download.variable, member: download.member, stepType: metadata.stepType, startStep: start, currentStep: end, array2d: &values) else { throw CurlMemoryDownloadError.invalidRangeResponse }
                    let dtSeconds = max(1, step - max(start, previousStep ?? start)) * 3600
                    if metadata.shortName == "z" { await values.data.multiplyAddConcurrent(multiply: 1 / 9.80665, add: 0) }
                    if let fma = download.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                        await values.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                    }
                    var grib = field.grib
                    grib.array = values
                    result.append(DecodedEnsembleField(variable: download.variable, unitsConverted: true, hour: step, member: download.member, shortName: metadata.shortName, stepType: metadata.stepType, stepRange: metadata.stepRange, grib: grib))
                    if step == lastHour {
                        await deaverager.remove(variable: download.variable, member: download.member)
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
                if let fma = download.variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                    await field.grib.array.data.multiplyAddConcurrent(multiply: fma.multiply, add: fma.add)
                }
            }
            let timestamp = run.add(hours: download.hour)
            var result = [DecodedEnsembleField]()
            // Separate source keys per consumer let omega and q share the same
            // temperature array without either removing the other's input.
            for (consumer, source) in sourceVariables[download.variable] ?? [] {
                guard field.unitsConverted else { throw CurlMemoryDownloadError.invalidRangeResponse }
                let sourceKey = "\(source.gribKey)>\(consumer.gribKey)"
                let key = download.variable == source ? sourceKey : consumer.gribKey
                await spatialInputs.set(variable: key, timestamp: timestamp, member: download.member, data: field.grib.array)
                guard let pair = await spatialInputs.getAllRemoving(variables: [sourceKey, consumer.gribKey], timestamp: timestamp, member: download.member) else { continue }
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
                result.append(DecodedEnsembleField(variable: decodedOutputs[consumer]!, unitsConverted: true, hour: download.hour, member: download.member, shortName: consumer.gribName!, stepType: "instant", stepRange: field.stepRange, grib: grib))
            }
            if !["2d", "rsn", "w", "q"].contains(download.variable.gribName) {
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
            let downloadTime = current.start.timeElapsedPretty()
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
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: values)
                let handle = try await GenericVariableHandle(variable: variable, time: run, member: member, fn: fn, domain: domain)
                curl.logger.info("\(variable.rawValue) member \(member): write=\(writeStart.timeElapsedPretty()), interpolation=\(interpolationTime), wait=\(writeJobWait), download=\(downloadTime), transpose=\(convertLoopTime)")
                return handle
            }
            // Convert an output once its final member has been written.
            if member == lastMember {
                let waitStart = DispatchTime.now()
                if let writeJob {
                    handles.append(try await writeJob.value)
                }
                writeJob = nil
                curl.logger.info("\(variable.rawValue) final write wait=\(waitStart.timeElapsedPretty())")
                let completedHandles = handles.filter { $0.variable.rawValue == variable.rawValue }
                handles.removeAll { $0.variable.rawValue == variable.rawValue }
                try await conversionJob?.value
                conversionJob = Task {
                    let handles = completedHandles
                    guard let first = handles.first else { throw CurlError.didNotFindAllVariablesInGribIndex }
                    let conversionStart = DispatchTime.now()
                    try await GenericVariableHandle.convert(application: application, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, concurrent: concurrent, writeUpdateJson: false, uploadQueues: uploadQueues, generateFullRun: domain.countEnsembleMember == 1, generateTimeSeries: generateTimeSeries, ensembleMeanDomain: domain.ensembleMeanDomain, precipitationProbability: true)
                    logger.info("Convert \(first.variable.rawValue): total=\(conversionStart.timeElapsedPretty())")
                }
            }
        }
        guard series.isEmpty, await inMemoryAccumulated.data.isEmpty, await spatialInputs.data.isEmpty else { throw CurlError.didNotFindAllVariablesInGribIndex }
        await progress.finish()
        if let writeJob { handles.append(try await writeJob.value) }
        try await conversionJob?.value
        guard handles.isEmpty else { throw CurlError.didNotFindAllVariablesInGribIndex }
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
