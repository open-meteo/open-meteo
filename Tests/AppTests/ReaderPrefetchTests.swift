import Foundation
import OmFileFormat
import OmFileIO
import Synchronization
import Testing
import VaporTesting
@testable import App

private final class PrefetchRecordingBackend: OmFileReaderBackend, Sendable {
    let bytes: Data
    let prefetches = Mutex(0)
    init(bytes: Data) { self.bytes = bytes }
    var count: Int { bytes.count }
    func getData(offset: Int, count: Int) async throws -> Data {
        bytes.subdata(in: offset..<offset + count)
    }
    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        try bytes.withUnsafeBytes { try fn(UnsafeRawBufferPointer(rebasing: $0[offset..<offset + count])) }
    }
    func prefetchData(offset: Int, count: Int) async throws {
        prefetches.withLock { $0 += 1 }
    }
}

@Suite struct ReaderPrefetchTests {
    @Test(arguments: [false, true])
    func singleVariableSelectionPreservesSections(sparse: Bool) throws {
        typealias Variables = ForecastapiResult<DummyDataProvider>.RequestVariables
        let temperature = try #require(ForecastVariable(rawValue: "temperature_850hPa"))
        let wind = try #require(ForecastVariable(rawValue: "wind_speed_10m"))
        let variables = Variables(
            currentVariables: sparse ? nil : [temperature],
            minutely15Variables: sparse ? [] : [wind],
            hourlyVariables: [temperature, wind],
            dailyVariables: sparse ? nil : [.temperature_2m_mean],
            weeklyVariables: [.windspeed_10m_mean], monthlyVariables: [.cloud_cover_mean])
        func describe(_ variables: Variables) -> [String] {
            let sections: [[String]] = [
                variables.currentVariables?.map { "current:\($0.rawValue)" } ?? [],
                variables.minutely15Variables?.map { "minutely15:\($0.rawValue)" } ?? [],
                variables.hourlyVariables?.map { "hourly:\($0.rawValue)" } ?? [],
                variables.dailyVariables?.map { "daily:\($0.rawValue)" } ?? [],
                variables.weeklyVariables?.map { "weekly:\($0.rawValue)" } ?? [],
                variables.monthlyVariables?.map { "monthly:\($0.rawValue)" } ?? []
            ]
            return sections.flatMap { $0 }
        }
        let expected = describe(variables)
        #expect(variables.count == expected.count)
        for index in 0..<variables.count {
            #expect(describe(variables.singleVariable(at: index)) == [expected[index]])
        }
    }

    @Test(arguments: [false, true])
    func responseKeepsNormalPrefetchSeparate(prefetch: Bool) async throws {
        let calls = Mutex((remote: 0, local: 0))
        let remoteEnabled = OpenMeteo.remoteDataDirectory != nil
        let provider = DummyDataProvider(onPrefetch: { variables in
            switch ReaderPrefetchPolicy.current {
            case .remoteOnly:
                #expect(!OmReaderPrefetch.pageInPayload)
                #expect(OmReaderPrefetch.remotePriority == .foreground)
                #expect(variables.count == 1)
                calls.withLock {
                    #expect($0.local == 0)
                    $0.remote += 1
                }
            case .all:
                #expect(OmReaderPrefetch.pageInPayload)
                #expect(prefetch)
                #expect(variables.count == 8)
                calls.withLock {
                    #expect($0.remote == (remoteEnabled ? 8 : 0))
                    $0.local += 1
                }
            }
        })
        let result = DummyDataProvider.makeData(timeformat: .iso8601, locationCount: 1, firstLocation: provider)
        let response = try await result.response(format: .json(fixedGenerationTime: 0), prefetch: prefetch, logger: .init(label: "test"))
        #expect(calls.withLock { $0.local } == (prefetch ? 1 : 0))
        #expect(calls.withLock { $0.remote } == (remoteEnabled ? 8 : 0))
        try await withApp { app in
            _ = try await response.body.collect(on: app.eventLoopGroup.next()).get()
        }
        #expect(calls.withLock { $0.local } == (prefetch ? 1 : 0))
        #expect(calls.withLock { $0.remote } == (remoteEnabled ? 8 : 0))
        #expect(ReaderPrefetchPolicy.current == .all)
        #expect(OmReaderPrefetch.remotePriority == .background)
    }

    @Test
    func normalPrefetchRemainsSequentialPerLocation() async throws {
        let state = Mutex((order: [Int](), active: 0))
        let template = DummyDataProvider.makeData(timeformat: .iso8601, locationCount: 1)
        let locations = (0..<3).map { index in
            let provider = DummyDataProvider(onPrefetch: { variables in
                guard ReaderPrefetchPolicy.current == .all else { return }
                #expect(variables.count == 8)
                state.withLock {
                    $0.order.append(index)
                    $0.active += 1
                    #expect($0.active == 1)
                }
                await Task.yield()
                state.withLock { $0.active -= 1 }
            })
            let location = template.results[0]
            return ForecastapiResult<DummyDataProvider>.PerLocation(
                timezone: location.timezone, time: location.time, locationId: index, results: [provider])
        }
        let result = ForecastapiResult<DummyDataProvider>(
            timeformat: template.timeformat, results: locations,
            currentVariables: template.variables.currentVariables, minutely15Variables: nil,
            hourlyVariables: template.variables.hourlyVariables, dailyVariables: template.variables.dailyVariables,
            weeklyVariables: nil, monthlyVariables: template.variables.monthlyVariables)
        _ = try await result.response(format: .json(fixedGenerationTime: 0), prefetch: true, logger: .init(label: "test"))
        #expect(state.withLock { $0.order } == [0, 1, 2])
        #expect(state.withLock { $0.active } == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func slowCoordinateDoesNotHoldBackLaterCoordinates() async throws {
        let state = Mutex((started: Set<Int>(), active: 0, maximum: 0))
        let (gate, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }
        let template = DummyDataProvider.makeData(timeformat: .iso8601, locationCount: 1)
        let locations = (0..<25).map { index in
            let provider = DummyDataProvider(onPrefetch: { variables in
                #expect(ReaderPrefetchPolicy.current == .remoteOnly)
                state.withLock {
                    $0.started.insert(index)
                    $0.active += 1
                    $0.maximum = max($0.maximum, $0.active)
                }
                defer { state.withLock { $0.active -= 1 } }
                if index == 0 && variables.currentVariables?.first?.rawValue == "temperature_2m" {
                    for await _ in gate {}
                }
            })
            let location = template.results[0]
            return ForecastapiResult<DummyDataProvider>.PerLocation(
                timezone: location.timezone, time: location.time, locationId: index, results: [provider])
        }
        let result = ForecastapiResult<DummyDataProvider>(
            timeformat: template.timeformat, results: locations,
            currentVariables: template.variables.currentVariables, minutely15Variables: nil,
            hourlyVariables: template.variables.hourlyVariables, dailyVariables: template.variables.dailyVariables,
            weeklyVariables: template.variables.dailyVariables, monthlyVariables: template.variables.monthlyVariables)
        let prefetch = Task { try await result.preloadRemoteLocations(logger: .init(label: "test"), concurrency: 4) }
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while state.withLock({ $0.started.count }) < 25 {
                try #require(ContinuousClock.now < deadline, "Later coordinates waited for the first batch")
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(state.withLock { $0.maximum } <= 4)
            #expect(state.withLock { $0.active } >= 1)
            release.finish()
            try await prefetch.value
            #expect(state.withLock { $0.active } == 0)
        } catch {
            release.finish()
            prefetch.cancel()
            _ = await prefetch.result
            throw error
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func variablesWithinCoordinateTakePriority() async throws {
        let state = Mutex((coordinates: [Int](), active: 0, maximum: 0))
        let (gate, release) = AsyncStream<Void>.makeStream()
        defer { release.finish() }
        let template = DummyDataProvider.makeData(timeformat: .iso8601, locationCount: 1)
        let locations = (0..<2).map { index in
            let provider = DummyDataProvider(onPrefetch: { variables in
                #expect(variables.hourlyVariables?.count == 1)
                state.withLock {
                    $0.coordinates.append(index)
                    $0.active += 1
                    $0.maximum = max($0.maximum, $0.active)
                }
                defer { state.withLock { $0.active -= 1 } }
                for await _ in gate {}
            })
            let location = template.results[0]
            return ForecastapiResult<DummyDataProvider>.PerLocation(
                timezone: location.timezone, time: location.time, locationId: index, results: [provider])
        }
        let result = ForecastapiResult<DummyDataProvider>(
            timeformat: template.timeformat, results: locations,
            currentVariables: nil, minutely15Variables: nil,
            hourlyVariables: ["temperature_2m", "temperature_500hPa", "wind_speed_850hPa", "relative_humidity_700hPa", "precipitation"].compactMap(ForecastVariable.init(rawValue:)),
            dailyVariables: nil, weeklyVariables: nil, monthlyVariables: nil)
        let prefetch = Task { try await result.preloadRemoteLocations(logger: .init(label: "test"), concurrency: 3) }
        do {
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while state.withLock({ $0.coordinates.count }) < 3 {
                try #require(ContinuousClock.now < deadline, "Variables within a coordinate were serialized")
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(state.withLock { $0.coordinates } == [0, 0, 0])
            release.finish()
            try await prefetch.value
            #expect(state.withLock { $0.coordinates.filter { $0 == 0 }.count } == 5)
            #expect(state.withLock { $0.coordinates.filter { $0 == 1 }.count } == 5)
            #expect(state.withLock { $0.maximum } == 3)
            #expect(state.withLock { $0.active } == 0)
        } catch {
            release.finish()
            prefetch.cancel()
            _ = await prefetch.result
            throw error
        }
    }

    @Test
    func remoteOnlySkipsLocalPayloadPrefetch() async throws {
        let fixture = try await makeElevationFile([1, 2, 3, 4])
        defer { fixture.remove() }
        let backend = PrefetchRecordingBackend(bytes: try Data(contentsOf: URL(fileURLWithPath: fixture.path)))
        let reader = try await OmFileReader(fn: backend).expectArray(of: Float.self)
        try await ReaderPrefetchPolicy.$current.withValue(.remoteOnly) {
            try await reader.willNeed3D(ny: 1, nx: 1, nTime: 4, nMembers: 1, location: 0..<1, level: 0, timeOffsets: (0..<4, 0..<4))
        }
        #expect(backend.prefetches.withLock { $0 } == 0)
        try await ReaderPrefetchPolicy.$current.withValue(.all) {
            try await reader.willNeed3D(ny: 1, nx: 1, nTime: 4, nMembers: 1, location: 0..<1, level: 0, timeOffsets: (0..<4, 0..<4))
        }
        #expect(backend.prefetches.withLock { $0 } > 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func remoteOnlyPrefetchesSurfaceFile() async throws {
        let values = (0..<10_000).map { Float(($0 * 7919) % 10007) }
        let fixture = try await makeElevationFile(values)
        defer { fixture.remove() }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: fixture.path))
        let requests = Mutex(0)
        let app = try await Application.make(.testing)
        app.get { _ in HTTPStatus.ok }
        app.get("surface.om") { request in
            let range = try #require(request.headers.first(name: .range))
            let bounds = range.dropFirst("bytes=".count).split(separator: "-")
            let lower = try #require(Int(bounds[0]))
            let upper = try #require(Int(bounds[1]))
            requests.withLock { $0 += 1 }
            return Response(status: .partialContent, body: .init(data: bytes.subdata(in: lower..<upper + 1)))
        }
        let cachePath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: cachePath) }
        do {
            try await app.server.start(address: .hostname("127.0.0.1", port: 0))
            let port = try #require(app.http.server.shared.localAddress?.port)
            let context = S3ServerHealth(logger: .init(label: "test"), servers: [.init(rawEndpoint: "http://127.0.0.1:\(port)/", profile: nil)])
            defer { Task { await context.stopMonitoring() } }
            let cache = try AtomicBlockCache(file: cachePath, blockSize: 64, blockCount: 4096)
            let backend = OmReaderBlockCache(
                backend: OmHttpReaderBackend(context: context, object: "surface.om", count: bytes.count, eTag: "\"test\"", lastModified: .now()),
                cache: AtomicCacheCoordinator(cache: cache), cacheKey: 123)
            let reader = try await OmFileReader(fn: backend).expectArray(of: Float.self)
            let before = requests.withLock { $0 }
            try await ReaderPrefetchPolicy.$current.withValue(.remoteOnly) {
                try await reader.willNeed3D(ny: 1, nx: 1, nTime: values.count, nMembers: 1, location: 0..<1, level: 0, timeOffsets: (0..<values.count, 0..<values.count))
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while requests.withLock({ $0 }) == before {
                try #require(ContinuousClock.now < deadline, "Remote surface payload was not prefetched")
                try await Task.sleep(for: .milliseconds(10))
            }
            var output = [Float](repeating: .nan, count: values.count)
            try await reader.read3D(into: &output, ny: 1, nx: 1, nTime: values.count, nMembers: 1, location: 0..<1, level: 0, timeOffsets: (0..<values.count, 0..<values.count))
            #expect(output == values)
            await app.server.shutdown()
            try await app.asyncShutdown()
        } catch {
            await app.server.shutdown()
            try await app.asyncShutdown()
            throw error
        }
    }
}
