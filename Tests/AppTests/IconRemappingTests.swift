// import Foundation
// import Testing
// import SwiftNetCDF
// import AsyncHTTPClient
// import Logging
// @testable import App
// @testable import ReducedLatLon

// @Suite(.serialized) struct IconRemappingTests {
//     @Test(arguments: [(43.18, -3.94), (0.0, 180.0), (89.99, 10.0)])
//     func refinementUsesOriginalCoordinates(_ coordinate: (Double, Double)) throws {
//         let (latitude, longitude) = coordinate
//         let latitudes = [latitude + 2e-8, latitude + 1e-8].map { $0 * .pi / 180 }
//         let longitudes = [Double](repeating: longitude * .pi / 180, count: 2)
//         let points = zip(latitudes, longitudes).map { ReducedLatLonPoint(latitudeRadians: $0, longitudeRadians: $1) }
//         if latitude == 43.18 { #expect(points[0] == points[1]) }
//         let fixture = try makeFixture(centers: points)
//         defer { fixture.remove() }
//         let radius = IconNativeGridIdentity.squaredChordDistance(meters: 4_000)
//         let grid = IconNativeGrid(storage: fixture.index, maximumChordDistanceSquared: radius,
//                                   nearbyMaximumChordDistanceSquared: radius)
//         let target = RegularGrid(nx: 1, ny: 1, latMin: Float(latitude), lonMin: Float(longitude), dx: 0.02, dy: 0.02)
//         #expect(IconRemapper.makeMapping(grid: grid, target: target, latitudes: latitudes, longitudes: longitudes) == [1])
//         let distant = RegularGrid(nx: 1, ny: 1, latMin: -80, lonMin: 0, dx: 0.02, dy: 0.02)
//         #expect(IconRemapper.makeMapping(grid: grid, target: distant, latitudes: latitudes, longitudes: longitudes) == [-1])
//     }

//     /// Preserve historical mappings exactly; compare generated EU/D2 mappings by nearest distance.
//     @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_REMAPPING_REFERENCES"] == "1"),
//           arguments: [IconDomains.icon, .iconEu, .iconD2, .iconEps, .iconEuEps, .iconD2Eps])
//     func compareReferenceWeights(_ domain: IconDomains) async throws {
//         let weights = try #require(try NetCDF.open(path: "\(domain.domainRegistry.directory)static/cdo_weights.nc", allowUpdate: false))
//         let src = try #require(try weights.getVariable(name: "src_address")?.asType(Int32.self)?.read())
//         let dst = try #require(try weights.getVariable(name: "dst_address")?.asType(Int32.self)?.read())
//         let sourceMask = try #require(try weights.getVariable(name: "src_grid_imask")?.asType(Int32.self)?.read())
//         let target = try #require(domain.grid as? RegularGrid)
//         var reference = [Int32](repeating: -1, count: target.count)
//         for i in src.indices { reference[Int(dst[i]) - 1] = src[i] - 1 }
//         let curl = Curl(logger: Logger(label: "icon-remapping-test"), client: HTTPClient.shared)
//         let actual = try await IconRemapper(curl: curl, domain: domain).mapping
//         if [.icon, .iconEps, .iconEuEps, .iconD2Eps].contains(domain) {
//             #expect(actual == reference)
//             return
//         }
//         let artifact = domain.nativeDomain.nativeGridFile
//         let file = "\(OpenMeteo.tempDirectory)download-\(artifact.registry.rawValue)/\(artifact.identity.sourceFile)"
//         let mesh = try #require(try NetCDF.open(path: file, allowUpdate: false))
//         let coordinates = try IconNativeGrid.Generator.readCoordinates(group: mesh, identity: artifact.identity)
//         let lat = coordinates.latitudes, lon = coordinates.longitudes
//         if domain == .iconD2 { try IconRemapper.adjustD2Boundary(mapping: &reference, mesh: mesh) }
//         let latMin = Double(String(target.latMin))!, lonMin = Double(String(target.lonMin))!
//         let dx = Double(String(target.dx))!, dy = Double(String(target.dy))!
//         var different = 0, worse = 0, rejected = 0, accepted = 0, maskedReference = 0
//         var maximumDistanceDifference = 0.0
//         for i in actual.indices {
//             let latitude = (latMin + Double(i / target.nx) * dy) * .pi / 180
//             let longitude = (lonMin + Double(i % target.nx) * dx) * .pi / 180
//             func distance(_ cell: Int32) -> Double {
//                 let cell = Int(cell)
//                 return 4 * (pow(sin((lat[cell] - latitude) / 2), 2)
//                     + cos(latitude) * cos(lat[cell]) * pow(sin((lon[cell] - longitude) / 2), 2))
//             }
//             if actual[i] < 0 {
//                 rejected += 1
//                 if reference[i] >= 0 {
//                     #expect(distance(reference[i]) > Double(artifact.identity.maximumChordDistanceSquared))
//                 }
//                 continue
//             }
//             accepted += 1
//             if actual[i] == reference[i] { continue }
//             if reference[i] < 0 {
//                 // Some historical weights baked in the field's missing-value mask.
//                 maskedReference += 1
//                 #expect(sourceMask[Int(actual[i])] == 0)
//                 continue
//             }
//             different += 1
//             let delta = distance(actual[i]) - distance(reference[i])
//             maximumDistanceDifference = max(maximumDistanceDifference, delta)
//             // Equidistant cells may have different IDs, especially at the global poles.
//             if delta > 1e-14 { worse += 1 }
//         }
//         print("\(domain): accepted=\(accepted), rejected=\(rejected), masked reference=\(maskedReference), different=\(different), farther=\(worse), max squared-chord difference=\(maximumDistanceDifference)")
//         #expect(accepted > 0)
//         #expect(worse == 0)
//     }
// }
