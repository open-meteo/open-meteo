import Foundation
@testable import App
import Testing
// import Vapor

@Suite struct DomainTests {
    @Test func regularGridSlice() {
        let grid = RegularGrid(nx: 10, ny: 10, latMin: 10, lonMin: 10, dx: 0.1, dy: 0.1)
        let sub = RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<6)
        #expect(sub.map { $0 } == [14, 15, 24, 25])
        #expect(sub[0] == 14)
        #expect(sub[1] == 15)
        #expect(sub[2] == 24)
        #expect(sub[3] == 25)
        #expect(RegularGridSlice(grid: grid, yRange: 1..<3, xRange: 4..<4).map { $0 }.isEmpty)
        #expect(RegularGridSlice(grid: grid, yRange: 1..<1, xRange: 4..<6).map { $0 }.isEmpty)

        let slice = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 10.4..<10.6, longitude: 10.7..<10.9))!
        #expect(slice.yRange == 4..<6)
        #expect(slice.xRange == 7..<9)
        #expect(slice.map { $0 } == [47, 48, 57, 58])
        
        /// Cams Europe grid uses negative dy
        let grid2 = RegularGrid(nx: 700, ny: 420, latMin: 71.95, lonMin: -24.95, dx: 0.1, dy: -0.1)
        let slice2 = grid2.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.15..<48.5, longitude: 5.0..<11))!
        #expect(slice2.yRange == 234..<268)
        #expect(slice2.xRange == 300..<360)
        #expect(slice2.count == 2040)
    }

    @Test func gaussianGridSlice() {
        let grid = GaussianGrid(type: .o1280)
        let sub = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8..<8.5))!
        #expect(sub.map { $0 } == [823061, 823062, 823063, 823064, 825629, 825630, 825631, 825632])

        let sub2 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8.5..<9))!
        #expect(sub2.map { $0 } == [823065, 823066, 823067, 825633, 825634, 825635])

        let sub3 = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 9..<9.5))!
        #expect(sub3.map { $0 } == [823068, 823069, 823070, 823071, 825636, 825637, 825638, 825639])
    }

    @Test func boundingBoxAtBorder() {
        let grid = RegularGrid(nx: 360, ny: 180, latMin: -90, lonMin: -180, dx: 1, dy: 1)
        let sliceLatBorder = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 88..<90, longitude: 10..<11))!
        #expect(sliceLatBorder.yRange == 178..<180)
        #expect(sliceLatBorder.xRange == 190..<191)
        let sliceSLatBorder = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: -90..<(-88), longitude: -11..<(-10)))!
        #expect(sliceSLatBorder.yRange == 0..<2)
        #expect(sliceSLatBorder.xRange == 169..<170)
        let sliceLonBorder = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: 10..<11, longitude: 179..<180))!
        #expect(sliceLonBorder.yRange == 100..<101)
        #expect(sliceLonBorder.xRange == 359..<360)
        let sliceELonBorder = grid.findBox(boundingBox: BoundingBoxWGS84(latitude: -11..<(-10), longitude: -180..<(-179)))!
        #expect(sliceELonBorder.yRange == 79..<80)
        #expect(sliceELonBorder.xRange == 0..<1)
    }

    @Test func ogcWkt2StringForKnownDomains() {
        let iconProj4 = IconDomains.icon.grid.crsWkt2
        #expect(iconProj4 == """
            GEOGCRS["WGS 84",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                UNIT["degree",0.0174532925199433]
                USAGE[
                    SCOPE["grid"],
                    BBOX[-90.0,-180.0,90.0,179.75]]
            ]
            """)

        let aromeProj4 = MeteoFranceDomain.arome_france.grid.crsWkt2
        #expect(aromeProj4 == """
            GEOGCRS["WGS 84",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                UNIT["degree",0.0174532925199433]
                USAGE[
                    SCOPE["grid"],
                    BBOX[37.5,-12.0,55.4,16.0]]
            ]
            """)

        let cmcGemContinentalProj4 = GemDomain.gem_hrdps_continental.grid.crsWkt2
        #expect(cmcGemContinentalProj4 == """
            PROJCRS["Rotated Lat/Lon",
                BASEGEOGCRS["WGS 84",
                    DATUM["World Geodetic System 1984",
                        ELLIPSOID["WGS 84",6378137,298.257223563]]],
                CONVERSION["Oblique Transformation",
                    METHOD["Oblique Transformation"],
                    PARAMETER["Latitude of rotated pole", 36.0885],
                    PARAMETER["Longitude of rotated pole", 245.305],
                    PARAMETER["Azimuth", 0.0]],
                CS[Cartesian,2],
                    AXIS["x",east],
                    AXIS["y",north],
                UNIT["degree",0.0174532925199433],
                USAGE[
                    SCOPE["grid"],
                    BBOX[39.626034,-133.62952,47.87646,-40.708527]]
            ]
            """)

        let cmcGemRegionalProj4 = GemDomain.gem_regional.grid.crsWkt2
        #expect(cmcGemRegionalProj4 == """
            PROJCRS["Stereographic",
                BASEGEOGCRS["WGS 84",
                    DATUM["World Geodetic System 1984",
                        ELLIPSOID["WGS 84",6371229.0,298.257223563]]],
                CONVERSION["Stereographic",
                    METHOD["Stereographic"],
                    PARAMETER["Latitude of natural origin", 57.295784],
                    PARAMETER["Longitude of natural origin", 249.0],
                    PARAMETER["Scale factor at natural origin", 1.0],
                    PARAMETER["False easting", 0.0],
                    PARAMETER["False northing", 0.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                UNIT["metre",1.0],
                USAGE[
                    SCOPE["grid"],
                    BBOX[18.145027,-142.89252,45.40545,-10.174438]]
            ]
            """)

        let dmiHarmonieProj4 = DmiDomain.harmonie_arome_europe.grid.crsWkt2
        #expect(dmiHarmonieProj4 == """
            PROJCRS["Lambert Conformal Conic",
                BASEGEOGCRS["WGS 84",
                    DATUM["World Geodetic System 1984",
                        ELLIPSOID["WGS 84",6378137,298.257223563]]],
                CONVERSION["Lambert Conformal Conic",
                    METHOD["Lambert Conformal Conic (2SP)"],
                    PARAMETER["Latitude of 1st standard parallel",55.5],
                    PARAMETER["Latitude of 2nd standard parallel",55.5],
                    PARAMETER["Latitude of false origin",55.5],
                    PARAMETER["Longitude of false origin",352.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                UNIT["metre",1],
                USAGE[
                    SCOPE["grid"],
                    BBOX[39.670998,-25.421997,62.667618,40.069855]]
            ]
            """)

        let ukmoRegionalDeterministicProj4 = UkmoDomain.uk_deterministic_2km.grid.crsWkt2
        #expect(ukmoRegionalDeterministicProj4 == """
            PROJCRS["Lambert Azimuthal Equal-Area",
                BASEGEOGCRS["WGS 84",
                    DATUM["World Geodetic System 1984",
                        ELLIPSOID["WGS 84",6371229.0,298.257223563]]],
                CONVERSION["Lambert Azimuthal Equal-Area",
                    METHOD["Lambert Azimuthal Equal-Area"],
                    PARAMETER["Latitude of natural origin", 54.9],
                    PARAMETER["Longitude of natural origin", -2.5],
                    PARAMETER["False easting", 0.0],
                    PARAMETER["False northing", 0.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                UNIT["metre",1.0],
                USAGE[
                    SCOPE["grid"],
                    BBOX[44.508755,-17.152863,61.92511,15.352753]]
            ]
            """)
        
        let o1280Proj4 = EcmwfEcpdsDomain.ifs.grid.crsWkt2
        #expect(o1280Proj4 == """
            GEOGCRS["WGS 84 / O1280 Gaussian Grid",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                UNIT["degree",0.0174532925199433],
                REMARK["Gaussian reduced grid O1280 (ECMWF)"],
                ID["gaussian_grid","O1280"],
                USAGE[
                    SCOPE["grid"],
                    BBOX[-90,-180.0,90,180]]
            ]
            """)
    }

    @Test func gridBoundsForKnownDomains() {
        let iconGridBounds = IconDomains.icon.grid.gridBounds
        #expect(iconGridBounds == GridBounds(lat_bounds: -90.0...90.0, lon_bounds: -180.0...179.75))

        let icondD2GridBounds = IconDomains.iconD2_15min.grid.gridBounds
        #expect(icondD2GridBounds == GridBounds(lat_bounds: 43.18...58.08, lon_bounds: -3.94...20.339998))

        let aromeGridBounds = MeteoFranceDomain.arome_france.grid.gridBounds
        #expect(aromeGridBounds == GridBounds(lat_bounds: 37.5...55.4, lon_bounds: -12.0...16.0))

        let cmcGemContinentalGridBounds = GemDomain.gem_hrdps_continental.grid.gridBounds
        #expect(cmcGemContinentalGridBounds == GridBounds(lat_bounds: 39.626034...47.87646, lon_bounds: -133.62952...(-40.708527)))

        let cmcGemRegionalGridBounds = GemDomain.gem_regional.grid.gridBounds
        #expect(cmcGemRegionalGridBounds == GridBounds(lat_bounds: 18.145027...45.40545, lon_bounds: -142.89252...(-10.174438)))

        let dmiHarmonieGridBounds = DmiDomain.harmonie_arome_europe.grid.gridBounds
        #expect(dmiHarmonieGridBounds == GridBounds(lat_bounds: 39.670998...62.667618, lon_bounds: -25.421997...40.069855))

        let ukmoRegionalDeterministicGridBounds = UkmoDomain.uk_deterministic_2km.grid.gridBounds
        #expect(ukmoRegionalDeterministicGridBounds == GridBounds(lat_bounds: 44.508755...61.92511, lon_bounds: -17.152863...15.352753))
    }
}
