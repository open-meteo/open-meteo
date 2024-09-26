// swift-tools-version:5.6

import PackageDescription
import Foundation

#if arch(x86_64)
// Docker and Ubuntu release system uses `march=skylake`
let mArch = ProcessInfo.processInfo.environment["MARCH_SKYLAKE"] == "TRUE" ? ["-march=skylake"] : ["-march=native"]
#else
let mArch: [String] = []
#endif

let swiftFlags: [PackageDescription.SwiftSetting] = [
    .unsafeFlags(["-cross-module-optimization", "-Ounchecked"],
    .when(configuration: .release))
]

let cFlags = [PackageDescription.CSetting.unsafeFlags(["-O3", "-fno-math-errno", "-fno-trapping-math", "-freciprocal-math", "-ffp-contract=fast"] + mArch)]
// Note: Fast math flags reduce performance for compression
let cFlagsPFor2D = [PackageDescription.CSetting.unsafeFlags(["-O3"] + mArch)]
let cFlagsPFor = [PackageDescription.CSetting.unsafeFlags(["-O3", "-w"] + mArch)]

/// Conditional support for Apache Arrow Parquet files
let enableParquet = ProcessInfo.processInfo.environment["ENABLE_PARQUET"] == "TRUE"

let package = Package(
    name: "OpenMeteoApi",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/google/flatbuffers.git", from: "24.3.25"),
        .package(url: "https://github.com/open-meteo/sdk.git", from: "1.16.0"),
        // .package(path: "../openmeteo-sdk-fork"),  // local forked version
        //.package(url: "https://github.com/open-meteo/sdk.git", branch: "add_ecmwf_long_window"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftNetCDF.git", from: "1.1.2"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftTimeZoneLookup.git", from: "1.0.7"),
        .package(url: "https://github.com/patrick-zippenfenig/SwiftEccodes.git", from: "1.0.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.68.0"),
    ] + (enableParquet ? [
        .package(url: "https://github.com/patrick-zippenfenig/SwiftArrowParquet.git", from: "1.0.0")
    ] : []),
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FlatBuffers", package: "flatbuffers"),
                .product(name: "OpenMeteoSdk", package: "sdk"),
                .product(name: "SwiftNetCDF", package: "SwiftNetCDF"),
                .product(name: "SwiftTimeZoneLookup", package: "SwiftTimeZoneLookup"),
                .product(name: "SwiftEccodes", package: "SwiftEccodes"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "_NIOFileSystem", package: "swift-nio"),
                "CHelper",
                "SwiftPFor2D",
                "CZlib",
                "CBz2lib"
            ] + (enableParquet ? [
                .product(name: "SwiftArrowParquet", package: "SwiftArrowParquet")
            ] : []),
            cSettings: cFlags,
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
            cSettings: cFlags,
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
            cSettings: cFlagsPFor2D,
            swiftSettings: swiftFlags
        ),
        .target(
            name: "CTurboPFor",
            cSettings: cFlagsPFor,
            swiftSettings: swiftFlags
        ),
    ]
)
