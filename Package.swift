// swift-tools-version:5.6

import PackageDescription
import Foundation

let cFlagsBase = ["-fno-math-errno", "-fno-trapping-math", "-freciprocal-math"]
let swiftFlags: [PackageDescription.SwiftSetting] = [
    .unsafeFlags(["-cross-module-optimization", "-Ounchecked"],
    .when(configuration: .release))
]

#if arch(x86_64)
let cFlags = cFlagsBase + ["-march=skylake"]
#else
let cFlags = cFlagsBase
#endif

/// Conditional support for Apache Arrow Parquet files
let enableParquet = ProcessInfo.processInfo.environment["ENABLE_PARQUET"] == "TRUE"

let package = Package(
    name: "OpenMeteoApi",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.13.1"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.67.4"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftNetCDF.git", from: "1.0.0"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftTimeZoneLookup.git", from: "1.0.1"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftEccodes.git", from: "0.1.5"),
        .package(url: "https://github.com/orlandos-nl/IkigaJSON.git", from: "2.0.0"),
    ] + (enableParquet ? [.package(url: "https://github.com/patrick-zippenfenig/SwiftArrowParquet.git", from: "0.0.0")] : []),
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftNetCDF", package: "SwiftNetCDF"),
                .product(name: "SwiftTimeZoneLookup", package: "SwiftTimeZoneLookup"),
                .product(name: "SwiftEccodes", package: "SwiftEccodes"),
                "CHelper",
                "SwiftPFor2D",
                "IkigaJSON",
                "CZlib",
                "CBz2lib"
            ] + (enableParquet ? [
                .product(name: "SwiftArrowParquet", package: "SwiftArrowParquet")
            ] : []),
            cSettings: [.unsafeFlags(cFlags)],
            swiftSettings: swiftFlags + (enableParquet ? [.define("ENABLE_PARQUET")] : [])
        ),
        .systemLibrary(
            name: "CZlib",
            pkgConfig: "z",
            providers: [.brew(["zlib"]), .apt(["libz-dev"])]
        ),
        .systemLibrary(
            name: "CBz2lib",
            pkgConfig: "bz2",
            providers: [.brew(["bzip2"]), .apt(["libbz2-dev"])]
        ),
        .target(
            name: "CHelper",
            cSettings: [.unsafeFlags(cFlags)],
            swiftSettings: swiftFlags
        ),
        .executableTarget(
            name: "openmeteo-api",
            dependencies: [.target(name: "App")]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [.target(name: "App")]
        ),
        .target(
            name: "SwiftPFor2D",
            dependencies: ["CTurboPFor", "CHelper"],
            cSettings: [.unsafeFlags(cFlags)],
            swiftSettings: swiftFlags
        ),
        .target(
            name: "CTurboPFor",
            cSettings: [.unsafeFlags(cFlags + ["-w"])], // disable all warnings, generated from macros
            swiftSettings: swiftFlags
        ),
    ]
)
