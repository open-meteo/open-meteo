import App
import Benchmark
import BmUtils
import Foundation

let latitude: Float = 52
let longitude: Float = 7

fileprivate extension TimerangeDt {
    static let exradTime = TimerangeDt(
        start: Timestamp(1900, 1, 1),
        to: Timestamp(2000, 1, 1),
        dtSeconds: 3600
    )
}

fileprivate extension Zensun {
    static var calcExtraTerrestrialRadiationBackwards: [Float] {
        Zensun.extraTerrestrialRadiationBackwards(
            latitude: latitude,
            longitude: longitude,
            timerange: TimerangeDt.exradTime
        )
    }
}

let benchmarks = {
    Benchmark.defaultConfiguration.maxDuration = .seconds(6)

    Benchmark(
        "Solar Position Calculation for 50 years, hourly",
        configuration: .init(thresholds: .p90WallClock(625))
    ) { bm in
        let _ = SolarPositionAlgorithm.sunPosition(timerange: TimerangeDt.exradTime)
    }

    Benchmark(
        "Calculate extra terrestrial radiation (100 years, hourly)",
        configuration: .init(thresholds: .p90WallClock(47))
    ) { bm in
        blackHole(Zensun.calcExtraTerrestrialRadiationBackwards)
    }

    let exrad = Zensun.calcExtraTerrestrialRadiationBackwards

    Benchmark(
        "Interpolate radiation to 15 minutes",
        configuration: .init(thresholds: .p90WallClock(246))
    ) { bm in
        let dtNew = TimerangeDt.exradTime.dtSeconds / 4
        let timeNew = TimerangeDt.exradTime.range.add(-TimerangeDt.exradTime.dtSeconds + dtNew).range(dtSeconds: dtNew)

        blackHole(
            exrad.interpolate(
                type: .solar_backwards_averaged,
                timeOld: TimerangeDt.exradTime,
                timeNew: timeNew,
                latitude: latitude,
                longitude: longitude,
                scalefactor: 100
            )
        )
    }
}
