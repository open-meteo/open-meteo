// import Foundation
// import Testing
// import SwiftEccodes
// import AsyncHTTPClient
// import Logging
// @testable import App

// @Suite struct IconD2ComparisonTests {
//     @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_D2_SAMPLES"] != nil),
//           arguments: ["", "-t2m"])
//     func d2MatchesDwd(_ field: String) async throws {
//         let directory = try #require(ProcessInfo.processInfo.environment["ICON_D2_SAMPLES"])
//         let domain = IconDomains.iconD2
//         // Local fixtures only: the mesh and reference fields must already exist.
//         try #require(FileManager.default.fileExists(atPath: "\(OpenMeteo.tempDirectory)download-dwd_icon_d2_native/\(domain.sourceGridIdentity.sourceFile)"))
//         let native = try SwiftEccodes.getMessages(fileName: "\(directory)/icon-d2\(field)-native.grib2", multiSupport: false)
//         let reference = try SwiftEccodes.getMessages(fileName: "\(directory)/icon-d2\(field)-regular.grib2", multiSupport: false)
//         try #require(native.count == 1 && reference.count == 1)
//         let nativeMessage = native[0], regular = reference[0]
//         let shortNames = field.isEmpty ? ["hsurf", "orog"] : ["2t", "t_2m"]
//         for message in [nativeMessage, regular] {
//             try #require(shortNames.contains(message.get(attribute: "shortName")?.lowercased() ?? ""))
//         }
//         for key in ["dataDate", "dataTime", "validityDate", "validityTime"] {
//             let expected = try #require(nativeMessage.getLong(attribute: key))
//             try #require(regular.getLong(attribute: key) == expected)
//         }

//         // Verify layout before comparing array offsets: matching dimensions alone is insufficient.
//         let target = domain.grid
//         try #require(regular.get(attribute: "gridType") == "regular_ll")
//         try #require(regular.getLong(attribute: "Nx") == target.nx)
//         try #require(regular.getLong(attribute: "Ny") == target.ny)
//         for (key, expected) in [("iScansNegatively", 0), ("jScansPositively", 1),
//                                 ("jPointsAreConsecutive", 0), ("alternativeRowScanning", 0)] {
//             try #require(regular.getLong(attribute: key) == expected)
//         }
//         for (point, label) in [(0, "First"), (target.count - 1, "Last")] {
//             let coordinate = target.getCoordinates(gridpoint: point)
//             let latitude = try #require(regular.get(attribute: "latitudeOf\(label)GridPointInDegrees").flatMap(Float.init))
//             let longitude = try #require(regular.get(attribute: "longitudeOf\(label)GridPointInDegrees").flatMap(Float.init))
//             let longitudeError = (longitude - coordinate.longitude).truncatingRemainder(dividingBy: 360)
//             try #require(abs(latitude - coordinate.latitude) < 0.0001)
//             try #require(min(abs(longitudeError), 360 - abs(longitudeError)) < 0.0001)
//         }
//         let curl = Curl(logger: Logger(label: "icon-d2-test"), client: HTTPClient.shared)
//         let remapper = try await IconRemapper(curl: curl, domain: domain)
//         let source = try IconNativeGribDecoder.decode(message: nativeMessage, identity: domain.sourceGridIdentity)
//         let actual = remapper.remap(source.data)
//         let expected = try regular.to2D(nx: target.nx, ny: target.ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array.data
//         try #require(actual.count == expected.count)
//         var finite = 0
//         var missing = 0
//         var differences = 0
//         for (value, reference) in zip(actual, expected) {
//             if reference.isNaN {
//                 missing += 1
//                 differences += value.isNaN ? 0 : 1
//             } else {
//                 finite += 1
//                 differences += value == reference ? 0 : 1
//             }
//         }
//         print("D2\(field) vs DWD: finite=\(finite), missing=\(missing), differences=\(differences)")
//         #expect(finite > 0 && missing > 0)
//         #expect(differences == 0)
//     }
// }
