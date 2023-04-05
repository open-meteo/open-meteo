// swift-tools-version:5.6

import PackageDescription

#if arch(x86_64)
let flagsCTurbo = ["-march=skylake", "-w"]
let flagsHelper = ["-march=skylake"]
#else
let flagsCTurbo = ["-w"]
let flagsHelper = [String]()
#endif

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
  ],
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
      ],
      swiftSettings: [
        .unsafeFlags(["-cross-module-optimization", "-Ounchecked"], .when(configuration: .release))
      ]
    ),
    .systemLibrary(name: "CZlib", pkgConfig: "z", providers: [.brew(["zlib"]), .apt(["libz-dev"])]),
    .systemLibrary(name: "CBz2lib", pkgConfig: "bz2", providers: [.brew(["bzip2"]), .apt(["libbz2-dev"])]),
    .target(name: "CHelper", cSettings: [.unsafeFlags(flagsHelper)]),
    .executableTarget(name: "openmeteo-api", dependencies: [.target(name: "App")]),
    .testTarget(name: "AppTests", dependencies: [.target(name: "App")]),
    .target(name: "SwiftPFor2D", dependencies: ["CTurboPFor", "CHelper"]),
    .target(name: "CTurboPFor", cSettings: [.unsafeFlags(flagsCTurbo)]), // disable all warnings, generated from macros
    //.testTarget(name: "SwiftPFor2DTests", dependencies: ["SwiftPFor2D", "CTurboPFor"]),
  ]
)
