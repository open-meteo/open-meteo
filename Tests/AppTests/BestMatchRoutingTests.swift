import Foundation
import Testing
@testable import App

@Suite struct BestMatchRoutingTests {
    @Test func contoursCoverTheirHomeAreaOnly() {
        #expect(BestMatchContours.france.contains(latitude: 50.95, longitude: 1.86)) // Calais
        #expect(BestMatchContours.france.contains(latitude: 48.58, longitude: 7.75)) // Strasbourg
        #expect(!BestMatchContours.france.contains(latitude: 48.57, longitude: 7.81)) // Kehl, across the Rhine
        #expect(BestMatchContours.france.contains(latitude: 50.1, longitude: 1.0)) // Strait of Dover, below the cut-out line
        #expect(BestMatchContours.france.contains(latitude: 49.8, longitude: -1.0)) // Channel up to the UK rectangle
        #expect(!BestMatchContours.france.contains(latitude: 49.5, longitude: -5.5)) // Celtic Sea, west of Pointe de Corsen
        #expect(BestMatchContours.benelux.contains(latitude: 49.61, longitude: 6.13)) // Luxembourg
        #expect(BestMatchContours.benelux.contains(latitude: 50.85, longitude: 5.69)) // Maastricht
        #expect(!BestMatchContours.benelux.contains(latitude: 50.78, longitude: 6.08)) // Aachen
        #expect(!BestMatchContours.benelux.contains(latitude: 53.55, longitude: 9.99)) // Hamburg
        #expect(!BestMatchContours.nordic.contains(latitude: 56.95, longitude: 24.11)) // Riga
    }

    @Test func firstMatchingRowServesTheCoordinate() {
        let expectations: [(city: String, lat: Float, lon: Float, region: String?)] = [
            ("Zürich", 47.37, 8.54, "Central Europe"),
            ("Paris", 48.86, 2.35, "France"),
            ("Brest", 48.39, -4.49, "France"),
            ("Calais", 50.95, 1.86, "France"),
            ("Marseille", 43.30, 5.37, "France"),
            ("Nice", 43.70, 7.27, "France"),
            ("Brussels", 50.85, 4.35, "Benelux"),
            ("Amsterdam", 52.37, 4.90, "Benelux"),
            ("Strasbourg", 48.58, 7.75, "France"),
            ("Kehl", 48.57, 7.81, "Central Europe"), // across the Rhine
            ("Luxembourg", 49.61, 6.13, "Benelux"),
            ("Maastricht", 50.85, 5.69, "Benelux"),
            ("Aachen", 50.78, 6.08, "Central Europe"),
            ("London", 51.51, -0.13, "United Kingdom & Ireland"),
            ("Dover", 51.13, 1.31, "United Kingdom & Ireland"),
            ("Dublin", 53.35, -6.26, "United Kingdom & Ireland"),
            ("Inverness", 57.48, -4.22, "United Kingdom & Ireland"),
            ("Lerwick", 60.15, -1.15, "United Kingdom & Ireland"), // inside the MET Nordic grid, UKMO wins
            ("Dunkirk", 51.03, 2.38, "France"),
            ("Strait of Dover", 50.1, 1.0, "France"), // below the cut-out line
            ("Baie de Seine", 49.8, -1.0, "France"), // Channel up to the UK rectangle
            ("Celtic Sea", 49.5, -5.5, "North Atlantic & North Sea"), // west of Pointe de Corsen, beyond the buffer
            ("Off Gris-Nez", 51.02, 1.5, "United Kingdom & Ireland"), // north of the cut-out line, inside the French coastal buffer
            ("Off Brighton", 50.4, 0.5, "United Kingdom & Ireland"), // north of the cut-out line
            ("Bergen", 60.39, 5.32, "Norway, Sweden & Finland"),
            ("Berlin", 52.52, 13.40, "Central Europe"),
            ("Hamburg", 53.55, 9.99, "Central Europe"),
            ("Vienna", 48.21, 16.37, "Central Europe"),
            ("Prague", 50.08, 14.44, "Central Europe"),
            ("Milan", 45.46, 9.19, "Central Europe"),
            ("Copenhagen", 55.68, 12.57, "Central Europe"),
            ("Malmö", 55.60, 13.00, "Central Europe"),
            ("Stockholm", 59.33, 18.07, "Norway, Sweden & Finland"),
            ("Oslo", 59.91, 10.75, "Norway, Sweden & Finland"),
            ("Helsinki", 60.17, 24.94, "Norway, Sweden & Finland"),
            ("Reykjavik", 64.15, -21.94, "North Atlantic & North Sea"),
            ("Ísafjörður", 66.07, -23.13, "North Atlantic & North Sea"),
            ("Grímsey", 66.54, -18.00, "North Atlantic & North Sea"),
            ("Tórshavn", 62.01, -6.77, "North Atlantic & North Sea"),
            ("Riga", 56.95, 24.11, "Baltic Sea region"),
            ("Warsaw", 52.23, 21.01, "Europe"),
            ("Rome", 41.90, 12.50, "Europe"),
            ("Madrid", 40.42, -3.70, "Europe"),
            ("Athens", 37.98, 23.73, "Europe"),
            ("Tokyo", 35.68, 139.69, "Japan"),
            ("Sapporo", 43.06, 141.35, "Japan"),
            ("Naha", 26.21, 127.68, "Japan"),
            ("Hateruma", 24.06, 123.78, "Japan"),
            ("Seoul", 37.57, 126.98, "Japan"), // the rectangle holds the Korean peninsula
            ("Shanghai", 31.23, 121.47, nil), // west of the rectangle
            ("New York", 40.71, -74.01, "North America"),
            ("Toronto", 43.65, -79.38, "North America"),
            ("Vancouver", 49.28, -123.12, "North America"),
            ("Yellowknife", 62.45, -114.37, "Canada"),
            ("Nome", 64.50, -165.40, "Northern North America"),
            ("Nuuk", 64.18, -51.72, "Northern North America"),
            ("Lisbon", 38.72, -9.14, "Europe"), // inside the RDPS grid, but east of its box
            ("Honolulu", 21.31, -157.86, nil),
            ("Sydney", -33.87, 151.21, nil),
            ("Nairobi", -1.29, 36.82, nil)
        ]
        for expectation in expectations {
            let region = MultiDomains.bestMatchRegion(lat: expectation.lat, lon: expectation.lon)?.name
            #expect(region == expectation.region, "\(expectation.city)")
        }
    }

    /// Building sources opens the file system manager, which needs the data directory.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: OpenMeteo.dataDirectory)))
    func rowsBuildReaderSources() async throws {
        for region in MultiDomains.bestMatchRegions {
            let sources = try await region.sources(true)
            #expect(!sources.primary.isEmpty, "\(region.name)")
        }
        let hourly = try await MultiDomains.bestMatchMapping(lat: 52.52, lon: 13.40, include15Min: false)
        #expect(hourly.primary.count > 4)
        #expect(hourly.requirePrimaryCoverage)
        // the 15-minutely ICON D2 storage joins the Central Europe row only when it is requested
        let quarterHourly = try await MultiDomains.bestMatchMapping(lat: 52.52, lon: 13.40, include15Min: true)
        #expect(quarterHourly.primary.count > hourly.primary.count)
    }
}
