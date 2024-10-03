import Benchmark

extension Dictionary where Key == BenchmarkMetric, Value == BenchmarkThresholds {
    public static func p50WallClock(_ milliseconds: Int) -> Self {
        return [
            .wallClock: .init(
                relative: [:],
                absolute: [.p50: .milliseconds(milliseconds)]
            )
        ]
    }
}
