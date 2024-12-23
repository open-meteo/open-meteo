import App
import Benchmark
import BmUtils
import Foundation
import SwiftPFor2D

let sizeMb = 128
func generateDummyTemperatureTimeseries(sizeMb: Int) -> [Float] {
    return (0..<1024 * 1024 / 4 * sizeMb).map {
        let x = Float($0)
        return sin(x * .pi / 24) * 10 + sin(x * .pi / 24 / 365.25) * 15 + sin(x * .pi / 7)
    }
}

let data = generateDummyTemperatureTimeseries(sizeMb: sizeMb)

let testOmBmFile = "\(OpenMeteo.dataDirectory)test.om"

func cleanUpTestOmBmFile() {
    try? FileManager.default.removeItem(atPath: testOmBmFile)
}

extension OmFileWriter {
    fileprivate static var smallChunkWriter: OmFileWriter {
        OmFileWriter(dim0: data.count / 1024, dim1: 1024, chunk0: 8, chunk1: 128)
    }

    fileprivate static var largeChunkWriter: OmFileWriter {
        OmFileWriter(dim0: data.count / 1024, dim1: 1024, chunk0: 1024, chunk1: 1024)
    }

    fileprivate var writeToMemory: Data {
        try! self.writeInMemory(compressionType: .p4nzdec256, scalefactor: 20, all: data)
    }

    fileprivate var writeToFile: FileHandle {
        try! self.write(
            file: testOmBmFile, compressionType: .p4nzdec256, scalefactor: 20, all: data,
            overwrite: true)
    }
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxDuration = .seconds(6)

    // Make sure directory exists
    try? FileManager.default.createDirectory(
        atPath: OpenMeteo.dataDirectory,
        withIntermediateDirectories: true
    )

    Benchmark(
        "Compression in memory, large chunks",
        configuration: .init(thresholds: .p90WallClock(191))
    ) { bm in
        for _ in bm.scaledIterations {
            blackHole(OmFileWriter.largeChunkWriter.writeToMemory)
        }
    }

    Benchmark(
        "Compression in memory, small chunks",
        configuration: .init(thresholds: .p90WallClock(199))
    ) { bm in
        for _ in bm.scaledIterations {
            blackHole(OmFileWriter.smallChunkWriter.writeToMemory)
        }
    }

    let compressed = OmFileWriter.smallChunkWriter.writeToMemory

    Benchmark(
        "Decompress from memory, small chunks",
        configuration: .init(thresholds: .p90WallClock(44))
    ) { bm in
        for _ in bm.scaledIterations {
            blackHole(try OmFileReader(fn: DataAsClass(data: compressed)).readAll())
        }
    }

    Benchmark(
        "Compress to file, small chunks",
        configuration: .init(
            thresholds: .p90WallClock(202),
            teardown: { cleanUpTestOmBmFile() }
        )
    ) { bm in
        for _ in bm.scaledIterations {
            blackHole(OmFileWriter.smallChunkWriter.writeToFile)
        }
    }

    Benchmark(
        "Decompress from file, small chunks",
        configuration: .init(
            thresholds: .p90WallClock(46),
            setup: {
                // make sure the file is written before reading from it
                let _ = OmFileWriter.smallChunkWriter.writeToFile
            },
            teardown: { cleanUpTestOmBmFile() }
        )
    ) { bm in
        for _ in bm.scaledIterations {
            blackHole(try OmFileReader(file: testOmBmFile).readAll())
        }
    }
}
