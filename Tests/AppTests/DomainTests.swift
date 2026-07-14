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
        let bb1 = BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8..<8.5)
        let sub = grid.findBox(boundingBox: bb1)!
        #expect(sub.map { $0 } == [823061, 823062, 823063, 823064, 825629, 825630, 825631, 825632])
        #expect(grid.estimatedNumberOfGridCells(boundingBox: bb1) == 8)

        let bb2 = BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 8.5..<9)
        let sub2 = grid.findBox(boundingBox: bb2)!
        #expect(sub2.map { $0 } == [823065, 823066, 823067, 825633, 825634, 825635])
        #expect(grid.estimatedNumberOfGridCells(boundingBox: bb2) == 6)

        let bb3 = BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: 9..<9.5)
        let sub3 = grid.findBox(boundingBox: bb3)!
        #expect(sub3.map { $0 } == [823068, 823069, 823070, 823071, 825636, 825637, 825638, 825639])
        #expect(grid.estimatedNumberOfGridCells(boundingBox: bb3) == 8)
        
        let bb4 = BoundingBoxWGS84(latitude: 45.0..<45.2, longitude: -9.5..<(-8))
        let sub4 = grid.findBox(boundingBox: bb4)!
        #expect(sub4.map { $0 } == [825504, 825505, 825506, 825507, 825508, 825509, 825510, 825511, 825512, 825513, 825514, 828076, 828077, 828078, 828079, 828080, 828081, 828082, 828083, 828084, 828085, 828086])
        #expect(grid.estimatedNumberOfGridCells(boundingBox: bb4) == 22)
    }
    
    @Test func gaussianGridArea() {
        // using longitudeOfFirstGridPointInDegrees longitudeOfLastGridPointInDegrees
        // latitudeOfLastGridPointInDegrees latitudeOfFirstGridPointInDegrees
        let grid = GaussianGridArea(type: .o1280, bounds: BoundingBoxWGS84(latitude: 33.005..<70.967, longitude: -11..<37))
//        #expect(grid.linePointCount.count == 541) // number of latitude lines
//        #expect(grid.linePointCount[0] == 147)
//        #expect(grid.linePointCount[1] == 147)
//        #expect(grid.linePointCount[2] == 147)
//        #expect(grid.linePointCount[3] == 148)
//        #expect(grid.linePointCount[4] == 149)
//        
//        #expect(grid.linePointCount[540] == 435)
//        #expect(grid.linePointCount[539] == 434)
//        #expect(grid.linePointCount[538] == 434)
//        #expect(grid.linePointCount[537] == 433)
        
        #expect(grid.count == 157257)
        let first = grid.getCoordinates(gridpoint: 0)
        #expect(first.latitude == 70.966606)
        #expect(first.longitude == -10.800018)
        
        let last = grid.getCoordinates(gridpoint: grid.count-1)
        #expect(last.latitude == 33.005272)
        #expect(last.longitude == 36.993866)
        
        let coord1 = grid.getCoordinates(gridpoint: 138822)
        #expect(coord1.latitude == 36.02812)
        #expect(coord1.longitude == 10.958549)
        
        let coord2 = grid.getCoordinates(gridpoint: 80994)
        #expect(coord2.latitude == 46.994724)
        #expect(coord2.longitude == -2.0454712)
        
        let coord3 = grid.getCoordinates(gridpoint: 144962)
        #expect(coord3.latitude == 34.973637)
        #expect(coord3.longitude == 0.0)
        
        let point = grid.findPoint(lat: 70.966606, lon: -10.800018)
        #expect(point == 0)
        
        let point2 = grid.findPoint(lat: 33.005272, lon: 36.993866)
        #expect(point2 == grid.count-1)
        
        let point3 = grid.findPoint(lat: 36.005272, lon: 10.993866)
        #expect(point3 == 138822)
        
        let point4 = grid.findPoint(lat: 47, lon: -2)
        #expect(point4 == 80994)
        
        let point5 = grid.findPoint(lat: 35, lon: -0.05)
        #expect(point5 == 144962)
        
        let point6 = grid.findPoint(lat: 35, lon: 0.05)
        #expect(point6 == 144962)
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
        // Following OGC WKT2 v2 https://www.ogc.org/standards/wkt-crs/
        // Different projections are used for different weather models
        // BBOX always contains the WGS84 coordinate of the south-wast and north-east coordinate
        // Note: dump proj4 string from GRIB files: `grib_ls -p short_name,projString <grib_file>`
        let iconProj4 = IconDomains.icon.grid.crsWkt2
        #expect(iconProj4 == """
            GEOGCRS["WGS 84",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433]
                USAGE[
                    SCOPE["grid"],
                    BBOX[-90.0,-180.0,90.0,179.75]]]
            """)

        let aromeProj4 = MeteoFranceDomain.arome_france.grid.crsWkt2
        #expect(aromeProj4 == """
            GEOGCRS["WGS 84",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433]
                USAGE[
                    SCOPE["grid"],
                    BBOX[37.5,-12.0,55.4,16.0]]]
            """)

        let cmcGemContinentalProj4 = GemDomain.gem_hrdps_continental.grid.crsWkt2
        #expect(cmcGemContinentalProj4 == """
            GEOGCRS["Rotated Lat/Lon",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",6371229.0,0.0]]],
                DERIVINGCONVERSION["Rotated Lat/Lon",
                    METHOD["PROJ ob_tran o_proj=longlat"],
                    PARAMETER["o_lon_p",0],
                    PARAMETER["o_lat_p",36.0885],
                    PARAMETER["lon_0",245.305]]
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433],
                USAGE[
                    SCOPE["grid"],
                    BBOX[39.626034,-133.62952,47.87646,-40.708527]]]
            """)

        let cmcGemRegionalProj4 = GemDomain.gem_regional.grid.crsWkt2
        #expect(cmcGemRegionalProj4 == """
            PROJCRS["Stereographic",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",6371229.0,0.0]]],
                CONVERSION["Stereographic",
                    METHOD["Stereographic"],
                    PARAMETER["Latitude of natural origin", 90.0],
                    PARAMETER["Longitude of natural origin", 249.0],
                    PARAMETER["Scale factor at natural origin", 1.0],
                    PARAMETER["False easting", 0.0],
                    PARAMETER["False northing", 0.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                    LENGTHUNIT["metre",1.0],
                USAGE[
                    SCOPE["grid"],
                    BBOX[18.145027,-142.89252,45.40545,-10.174438]]]
            """)

        let dmiHarmonieProj4 = DmiDomain.harmonie_arome_europe.grid.crsWkt2
        #expect(dmiHarmonieProj4 == """
            PROJCRS["Lambert Conic Conformal",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",6371229.0,0.0]]],
                CONVERSION["Lambert Conic Conformal",
                    METHOD["Lambert Conic Conformal (2SP)"],
                    PARAMETER["Latitude of 1st standard parallel",55.5],
                    PARAMETER["Latitude of 2nd standard parallel",55.5],
                    PARAMETER["Latitude of false origin",55.5],
                    PARAMETER["Longitude of false origin",352.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                    LENGTHUNIT["metre",1],
                USAGE[
                    SCOPE["grid"],
                    BBOX[39.670998,-25.421997,62.667618,40.069855]]]
            """)

        let ukmoRegionalDeterministicProj4 = UkmoDomain.uk_deterministic_2km.grid.crsWkt2
        #expect(ukmoRegionalDeterministicProj4 == """
            PROJCRS["Lambert Azimuthal Equal-Area",
                BASEGEOGCRS["GCS_Sphere",
                    DATUM["D_Sphere",
                        ELLIPSOID["Sphere",6371229.0,0.0]]],
                CONVERSION["Lambert Azimuthal Equal-Area",
                    METHOD["Lambert Azimuthal Equal-Area"],
                    PARAMETER["Latitude of natural origin", 54.9],
                    PARAMETER["Longitude of natural origin", -2.5],
                    PARAMETER["False easting", 0.0],
                    PARAMETER["False northing", 0.0]],
                CS[Cartesian,2],
                    AXIS["easting",east],
                    AXIS["northing",north],
                    LENGTHUNIT["metre",1.0],
                USAGE[
                    SCOPE["grid"],
                    BBOX[44.508755,-17.152863,61.92511,15.352753]]]
            """)

        let o1280Proj4 = EcmwfEcpdsDomain.ifs.grid.crsWkt2
        #expect(o1280Proj4 == """
            GEOGCRS["Reduced Gaussian Grid",
                DATUM["World Geodetic System 1984",
                    ELLIPSOID["WGS 84",6378137,298.257223563]],
                CS[ellipsoidal,2],
                    AXIS["latitude",north],
                    AXIS["longitude",east],
                    ANGLEUNIT["degree",0.0174532925199433],
                REMARK["Reduced Gaussian Grid O1280 (ECMWF)"],
                USAGE[
                    SCOPE["grid"],
                    BBOX[-90,-180.0,90,180]]]
            """)
    }

    @Test func gridBoundsForKnownDomains() {
        let camsEuropeBounds = CamsDomain.cams_europe.grid.gridBounds
        #expect(abs(camsEuropeBounds.lat_bounds.lowerBound - 30.05) < 0.0001)
        #expect(camsEuropeBounds.lat_bounds.upperBound == 71.95)
        #expect(camsEuropeBounds.lon_bounds == -24.95...44.95)

        let gaussianBounds = GaussianGrid(type: .o320).gridBounds
        #expect(gaussianBounds.lat_bounds.lowerBound < gaussianBounds.lat_bounds.upperBound)
        #expect(gaussianBounds.lon_bounds == -180...180)

        let gaussianAreaBounds = GaussianGridArea(
            type: .o320,
            bounds: BoundingBoxWGS84(latitude: 30..<70, longitude: -20..<40)
        ).gridBounds
        #expect(gaussianAreaBounds == GridBounds(lat_bounds: 30...70, lon_bounds: -20...40))

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
    
    @Test func ukvArea() {
        #expect(RegionGeometry.isInUKVArea(lat: 50.413732848903294, lon: 0.18312197439166766))
        #expect(!RegionGeometry.isInUKVArea(lat: 50.26080458809449, lon: 1.1836113344081411))
        #expect(!RegionGeometry.isInUKVArea(lat: 49.553874448314076, lon: 2.289155264059019))
    }
}
