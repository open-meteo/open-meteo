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
    .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
    .package(url: "https://github.com/patrick-zippenfenig/SwiftNetCDF.git", from: "1.0.0"),
    .package(url: "https://github.com/patrick-zippenfenig/SwiftTimeZoneLookup.git", from: "1.0.0"),
    .package(url: "https://github.com/orlandos-nl/IkigaJSON.git", from: "2.0.0"),
    //.package(name: "SwiftPFor2D", path: "/Users/om/Documents/SwiftPFor2D"),
    // NOTE: taged releases do not work, because of unsafe flags....
    //.package(url: "git@gitlab.com:open-meteo/SwiftPFor2D.git", .branch("main"))
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Leaf", package: "leaf"),
        .product(name: "SwiftNetCDF", package: "SwiftNetCDF"),
        .product(name: "SwiftTimeZoneLookup", package: "SwiftTimeZoneLookup"),
        "CHelper",
        "SwiftPFor2D",
        "IkigaJSON",
        "CZlib"
      ],
      swiftSettings: [
        .unsafeFlags(["-cross-module-optimization", "-Ounchecked"], .when(configuration: .release))
      ]
    ),
    .systemLibrary(name: "CZlib", pkgConfig: "z", providers: [.brew(["zlib"]), .apt(["libz-dev"])]),
    .target(name: "CHelper", cSettings: [.unsafeFlags(flagsHelper)]),
    .executableTarget(name: "openmeteo-api", dependencies: [.target(name: "App")]),
    .testTarget(name: "AppTests", dependencies: [.target(name: "App")]),
    .target(name: "SwiftPFor2D", dependencies: ["CTurboPFor"]),
    .target(name: "CTurboPFor", cSettings: [.unsafeFlags(flagsCTurbo)]), // disable all warnings, generated from macros
    //.testTarget(name: "SwiftPFor2DTests", dependencies: ["SwiftPFor2D", "CTurboPFor"]),
  ]
)
