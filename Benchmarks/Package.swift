// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
    ],
    targets: [
        .target(
            name: "BmUtils",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/Utils"
        ),
    ]
)

// Benchmark of meteorological calculations
package.targets += [
    .executableTarget(
        name: "OmMeteoBenchmarks",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "App", package: "open-meteo"),
            "BmUtils",
        ],
        path: "Benchmarks/Meteo",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]

// Benchmark of file writing / reading
package.targets += [
    .executableTarget(
        name: "OmFileWriterBenchmarks",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "App", package: "open-meteo"),
            .product(name: "SwiftPFor2D", package: "open-meteo"),
            "BmUtils",
        ],
        path: "Benchmarks/OmFileWriter",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    ),
]