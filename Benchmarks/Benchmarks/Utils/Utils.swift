import Benchmark

extension Dictionary where Key == BenchmarkMetric, Value == BenchmarkThresholds {
    public static func p90WallClock(_ milliseconds: Int) -> Self {
        return [
            .wallClock: .init(
                absolute: [
                    .p90: .milliseconds(milliseconds),
                ]
            ),
        ]
    }
}
