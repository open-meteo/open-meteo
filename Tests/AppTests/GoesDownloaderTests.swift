import Foundation
import Testing
import SwiftNetCDF
import OmFileIO
import OmFileFormat
@testable import App

@Suite struct GoesDownloaderTests {
    static let key = "ABI-L2-DSRF/2026/307/00/OR_ABI-L2-DSRF-M6_G19_s20263070000210_e20263070009518_c20263070015556.nc"
    func scan(_ minute: Int, tag: String = "a") -> GoesDownloader.Scan {
        GoesDownloader.Scan(key: Self.key.replacingOccurrences(of: "s20263070000210", with: "s202630700\(minute.zeroPadded(len: 2))210"), eTag: tag)!
    }

    func scan(endingAt time: Timestamp) -> GoesDownloader.Scan {
        let start = time.add(-GoesDomain.goes19.dtSeconds)
        let year = start.toComponents().year
        let day = ((start.timeIntervalSince1970 - Timestamp(year, 1, 1).timeIntervalSince1970) / 86400 + 1).zeroPadded(len: 3)
        let hour = start.hour.zeroPadded(len: 2), minute = start.minute.zeroPadded(len: 2)
        return GoesDownloader.Scan(key: "ABI-L2-DSRF/\(year)/\(day)/\(hour)/OR_ABI-L2-DSRF-M6_G19_s\(year)\(day)\(hour)\(minute)210_eunused_cunused.nc", eTag: "a")!
    }

    @Test func rowChunksPreserveStripReads() async throws {
        let nx = 1030, ny = 5
        let values = (0..<nx * ny).map { $0 % 17 == 0 ? Float.nan : Float($0 % 1501) }
        let writer = OmFileWriterHelper(dimensions: [ny, nx], chunks: [1, 1024])
        let file = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: values)
        let reader = try await OmFileReader(fn: MmapFile(fn: file)).expectArray(of: Float.self)
        for row in stride(from: 0, to: ny, by: 2) {
            let end = min(row + 2, ny)
            let strip = try await reader.read(range: [UInt64(row)..<UInt64(end), 0..<UInt64(nx)])
            for (actual, expected) in zip(strip, values[row * nx..<end * nx]) {
                #expect(actual == expected || (actual.isNaN && expected.isNaN))
            }
        }
    }

    @Test func invalidScanTimingIsRejected() throws {
        let scan = scan(0)
        let epoch = Double(Timestamp(2000, 1, 1, 12).timeIntervalSince1970)
        let start = Double(scan.start.timeIntervalSince1970) + 0.1 - epoch
        let valid = try GoesDownloader.validatedScanTimes(bounds: [start, start + 570.8], scan: scan)
        #expect(abs(valid.end - valid.start - 570.8) < 0.001)
        for bounds: [Double] in [[], [-999, -999], [start, start], [start, start + 100], [.nan, .nan], [start, .infinity], [start + 600, start + 1170.8]] {
            #expect(throws: GoesDownloader.InvalidScanTimes.self) {
                try GoesDownloader.validatedScanTimes(bounds: bounds, scan: scan)
            }
        }
        // Optional real NOAA file with missing time bounds (2025-05-21 17:30).
        if let path = ProcessInfo.processInfo.environment["GOES_INVALID_TIME_TEST_FILE"] {
            let nc = try #require(try NetCDF.open(path: path, allowUpdate: false))
            #expect(throws: GoesDownloader.InvalidScanTimes.self) {
                try GoesDownloader.decode(nc: nc, scan: scan)
            }
        }
    }

    @Test func filenameAndIntervalEnd() {
        let file = scan(0)
        #expect(file.start == Timestamp(2026, 11, 3, 0, 0, 21))
        #expect(file.time == Timestamp(2026, 11, 3, 0, 10))
        #expect(GoesDownloader.Scan(key: Self.key.replacingOccurrences(of: "DSRF", with: "DSIF"), eTag: "a") == nil)
        #expect(GoesDownloader.Scan(key: Self.key.replacingOccurrences(of: "M6", with: "M3"), eTag: "a") == nil)
        #expect(GoesDownloader.Scan(key: Self.key.replacingOccurrences(of: "G19", with: "G18"), eTag: "a") == nil)
        let endOfYear = Self.key.replacingOccurrences(of: "s20263070000210", with: "s20263652350210")
        #expect(GoesDownloader.Scan(key: endOfYear, eTag: "a")?.time == Timestamp(2027, 1, 1))
    }

    @Test func completedStateExpiresByAcquisitionTime() {
        let oldest = scan(0), newer = scan(10)
        let now = oldest.start.add(days: 3)
        let completed: Set<String> = [oldest.identity, newer.identity, "invalid"]
        #expect(GoesDownloader.recentCompleted(completed, lookbackDays: 3, now: now) == [oldest.identity, newer.identity])
        #expect(GoesDownloader.recentCompleted(completed, lookbackDays: 3, now: now.add(1)) == [newer.identity])
        #expect(GoesDownloader.recentCompleted(completed, lookbackDays: 1, now: now).isEmpty)
        // Historical backfills must not accumulate expired checkpoint entries.
        #expect(GoesDownloader.recentCompleted(completed, lookbackDays: 3, now: now.add(days: 30)).isEmpty)
    }

    @Test func sharedS3ListingPreservesExistingCheckpointIdentities() {
        let legacy = scan(0, tag: "&quot;abc123&quot;")
        let listed = scan(0, tag: "\"abc123\"")
        #expect(listed.identity == legacy.identity)
        #expect(GoesDownloader.batches(scans: [listed], completed: [legacy.identity]).isEmpty)
        let replaced = scan(0, tag: "\"new-etag\"")
        #expect(GoesDownloader.batches(scans: [replaced], completed: [legacy.identity]) == [[replaced]])
    }

    @Test func lateArrivalAndReplacementAreNotLostBehindWatermark() {
        let first = scan(0), late = scan(10), latest = scan(30)
        let completed: Set<String> = [first.identity, latest.identity]
        #expect(GoesDownloader.batches(scans: [first, latest], completed: completed).isEmpty)
        #expect(GoesDownloader.batches(scans: [first, late, latest], completed: completed) == [[first, late, latest]])
        let replaced = scan(0, tag: "new")
        #expect(GoesDownloader.batches(scans: [replaced, latest], completed: completed) == [[replaced, latest]])
    }

    @Test func chunkBatchRetainsGapEndpointsAndRetries() {
        let scans = [scan(0), scan(10), scan(30), scan(40), scan(50)]
        #expect(GoesDownloader.batches(scans: scans, completed: []) == [scans])
        // Earlier invocations completed the first observations; retain the gap endpoint.
        #expect(GoesDownloader.batches(scans: scans, completed: Set(scans[0...2].map(\.identity))) == [Array(scans[2...4])])
        // Pending observations separated by completed scans must not cause those
        // observations to be replaced by interpolation in the merged conversion.
        #expect(GoesDownloader.batches(scans: scans, completed: Set(scans[1...3].map(\.identity))) == [scans])
        #expect(GoesDownloader.batches(scans: [], completed: []).isEmpty)
    }

    @Test func batchesMatchOmChunks() {
        let domain = GoesDomain.goes19
        let duration = domain.dtSeconds * domain.omFileLength
        let boundary = Timestamp(Timestamp(2026, 11, 3).timeIntervalSince1970 / duration * duration)
        let scans = (0..<domain.omFileLength * 2).map { scan(endingAt: boundary.add($0 * domain.dtSeconds)) }
        let batches = GoesDownloader.batches(scans: scans, completed: [])
        #expect(batches.count == 2)
        #expect(batches.map(\.count) == [domain.omFileLength, domain.omFileLength])
        #expect(batches.flatMap { $0 } == scans)
        for batch in batches {
            let time = TimerangeDt(start: batch.first!.time, to: batch.last!.time.add(domain.dtSeconds), dtSeconds: domain.dtSeconds)
            // Exactly one file would be opened by OmFileSplitter for this batch.
            #expect(time.toIndexTime().divideRoundedUp(divisor: domain.omFileLength).count == 1)
        }
        // A failed second chunk is retried without downloading/writing the first again.
        let completed = Set(batches[0].map(\.identity))
        #expect(GoesDownloader.batches(scans: scans, completed: completed) == [batches[1]])
    }

    @Test func shiftedMidnightScanBelongsToNextChunk() {
        let domain = GoesDomain.goes19
        let duration = domain.dtSeconds * domain.omFileLength
        let boundary = Timestamp(Timestamp(2026, 11, 3).timeIntervalSince1970 / duration * duration)
        let before = scan(endingAt: boundary.add(-domain.dtSeconds))
        let midnight = scan(endingAt: boundary)
        let after = scan(endingAt: boundary.add(domain.dtSeconds))
        #expect(midnight.start < boundary)
        #expect(midnight.time == boundary)
        #expect(GoesDownloader.batches(scans: [before, midnight, after], completed: []) == [[before], [midnight, after]])
        #expect(GoesDownloader.batches(scans: [before, midnight, after], completed: [before.identity]) == [[midnight, after]])
    }

    @Test func projectionAndNativeGridOrientation() {
        let projection = GoesProjection()
        let nadir = projection.inverse(x: 0, y: 0)
        #expect(abs(nadir.latitude) < 0.0001)
        #expect(abs(nadir.longitude + 75) < 0.0001)
        for (lat, lon): (Float, Float) in [(40.7, -74), (-33.4, -70.7), (0, -75), (60, -100)] {
            let xy = projection.forward(latitude: lat, longitude: lon)
            let back = projection.inverse(x: xy.x, y: xy.y)
            #expect(abs(back.latitude - lat) < 0.0001)
            #expect(abs(back.longitude - lon) < 0.0001)
            let grid = GoesDomain.fixedGrid
            let point = grid.findPoint(lat: lat, lon: lon)!
            let coords = grid.getCoordinates(gridpoint: point)
            #expect(abs(coords.latitude - lat) < 0.05)
            #expect(abs(coords.longitude - lon) < 0.05)
            #expect(grid.findPointInterpolated(lat: lat, lon: lon) != nil)
        }
        #expect(GoesDomain.fixedGrid.findPoint(lat: 0, lon: 105) == nil)
        #expect(GoesDomain.fixedGrid.getCoordinates(gridpoint: 0).latitude.isNaN)
        #expect(GoesDomain.fixedGrid.getCoordinates(gridpoint: 1000 * 5424 + 2712).latitude < 0)
        #expect(GoesDomain.fixedGrid.getCoordinates(gridpoint: 4423 * 5424 + 2712).latitude > 0)
    }

    @Test func unsignedPackingAndQualityMask() {
        #expect(GoesDownloader.radiation(raw: 40000, quality: 0, fill: 65535, scale: 0.02, offset: 0) == 800)
        #expect(GoesDownloader.radiation(raw: 65535, quality: 0, fill: 65535, scale: 0.02, offset: 0).isNaN)
        #expect(GoesDownloader.radiation(raw: 40000, quality: 1, fill: 65535, scale: 0.02, offset: 0) == 800)
        #expect(GoesDownloader.radiation(raw: 65535, quality: 1, fill: 65535, scale: 0.02, offset: 0).isNaN)
        #expect(GoesDownloader.radiation(raw: 40000, quality: 2, fill: 65535, scale: 0.02, offset: 0).isNaN)
        #expect(GoesDownloader.radiation(raw: 40000, quality: 255, fill: 65535, scale: 0.02, offset: 0).isNaN)
        #expect(GoesDownloader.radiation(raw: 40000, quality: 1, fill: 65535, scale: 0.04, offset: 0).isNaN)
        #expect(GoesDownloader.radiation(raw: 0, quality: 1, fill: 65535, scale: 0.02, offset: -1).isNaN)
    }

    @Test func lowSunRetrievalsSurviveScanTimeCorrection() {
        // Actual DQF=1 pixels from NOAA's 2026-11-01 scans at New York.
        let samples: [(Timestamp, UInt16)] = [
            (Timestamp(2026, 11, 1, 12, 10), 1654),
            (Timestamp(2026, 11, 1, 13, 40), 9751),
            (Timestamp(2026, 11, 1, 20, 0), 12473)
        ]
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 40.702015, lonMin: -74.017105, dx: 1, dy: 1)
        for (time, raw) in samples {
            let end = Double(time.timeIntervalSince1970)
            let acquisition = GoesDownloader.scanSeconds(sourceRow: 740, column: 2751, start: end - 579, end: end - 8.1)
            var values = [GoesDownloader.radiation(raw: raw, quality: 1, fill: 65535, scale: 0.02289028, offset: 0)]
            Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &values, grid: grid, locationRange: 0..<1,
                timerange: TimerangeDt(start: time, nTime: 1, dtSeconds: 600), sunDeclinationCutOffDegrees: 1,
                scanTimeDifferenceHours: [(acquisition - end) / 3600])
            #expect(values[0].isFinite && values[0] > 0 && values[0] <= 1500)
        }
    }

    @Test func acquisitionOffsetsFollowSwathsAndStayWithinScan() {
        let start = 21.0, end = 591.8
        let north = GoesDownloader.scanSeconds(sourceRow: 0, column: 2712, start: start, end: end)
        let south = GoesDownloader.scanSeconds(sourceRow: 5423, column: 2712, start: start, end: end)
        #expect(north < 30)
        #expect(south > 580)
        #expect(north >= start && south <= end)
        let west = GoesDownloader.scanSeconds(sourceRow: 2712, column: 1000, start: start, end: end)
        let east = GoesDownloader.scanSeconds(sourceRow: 2712, column: 4000, start: start, end: end)
        #expect(west < east)
        #expect((east - 600) / 3600 < 0) // Offsets are relative to the interval END.
    }

    @Test func solarConversionUsesAcquisitionTime() {
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 0, lonMin: -75, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2026, 3, 20, 12), nTime: 1, dtSeconds: 600)
        var early: [Float] = [100], late: [Float] = [100]
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &early, grid: grid, locationRange: 0..<1,
            timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: [-9.0 / 60])
        Zensun.instantaneousSolarRadiationToBackwardsAverages(timeOrientedData: &late, grid: grid, locationRange: 0..<1,
            timerange: time, sunDeclinationCutOffDegrees: 1, scanTimeDifferenceHours: [-1.0 / 60])
        #expect(early[0] > late[0])
        #expect(early[0].isFinite && late[0].isFinite)
    }

    /// Opt-in real NOAA fixture, kept out of the repository (12 MB compressed).
    @Test func realNoaaFile() async throws {
        guard let path = ProcessInfo.processInfo.environment["GOES_TEST_FILE"] else { return }
        let nc = try #require(try NetCDF.open(path: path, allowUpdate: false))
        let values = try GoesDownloader.decode(nc: nc, scan: scan(0))
        #expect(values.count == 5424 * 5424)
        #expect(values[0].isNaN) // Space must never become nighttime zero.
        #expect(values.contains { $0 > 100 && $0 < 1500 })
        #expect(values.contains { $0 == 0 })
        #expect(!values.contains { $0.isInfinite || $0 < 0 })

        // Concurrent in-memory opening and decoding must match the serial result,
        // including missing pixels. Exercise the same helper used by the downloader.
        let buffer = try Data(contentsOf: URL(fileURLWithPath: path))
        let fileScan = scan(0)
        let matches: [Bool] = try await [0, 1].mapConcurrent(nConcurrent: 2) { _ in
            let decoded = try buffer.withUnsafeBytes { bytes in
                let file = try #require(try NetCDF.open(memory: bytes))
                return try GoesDownloader.decode(nc: file, scan: fileScan)
            }
            return decoded.count == values.count && zip(decoded, values).allSatisfy {
                $0 == $1 || ($0.isNaN && $1.isNaN)
            }
        }
        #expect(matches == [true, true])
    }
}
