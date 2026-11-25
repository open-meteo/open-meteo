import Foundation

/// GOES-East ABI fixed grid. Coordinates are retained at the native 2 km sampling,
/// with rows flipped to south-to-north to match the other Open-Meteo grids.
enum GoesDomain: String, CaseIterable, GenericDomain {
    case goes19
    var domainRegistry: DomainRegistry { .noaa_goes19 }
    var domainRegistryStatic: DomainRegistry? { domainRegistry }
    var dtSeconds: Int { 600 }
    var updateIntervalSeconds: Int { 600 }
    /// One file chunk per day (GMT+0)
    var omFileLength: Int { 1 * 24 * 6 }
    var countEnsembleMember: Int { 1 }
    var masterTimeRange: Range<Timestamp>? { nil }
    var generateFullRun: Bool { false }
    var grid: any Gridable { Self.fixedGrid }

    static let fixedGrid = ProjectionGrid(nx: 5424, ny: 5424,
        latitudeProjectionOrigin: -0.151844 * Float(GoesProjection.height),
        longitudeProjectionOrigin: -0.151844 * Float(GoesProjection.height),
        dx: 0.000056 * Float(GoesProjection.height), dy: 0.000056 * Float(GoesProjection.height),
        projection: GoesProjection())
}

enum GoesVariable: String, GenericVariable {
    case shortwave_radiation
    var omFileName: (file: String, level: Int) { (rawValue, 0) }
    var scalefactor: Float { 1 }
    var interpolation: ReaderInterpolation { .solar_backwards_missing_not_averaged }
    var unit: SiUnit { .wattPerSquareMetre }
    var isElevationCorrectable: Bool { false }
    var storePreviousForecast: Bool { false }
}

/// GOES-R PUG Vol. 3, section 5.1.2.8: geostationary projection with x sweep.
/// Use doubles internally: the ray/ellipsoid intersection loses precision at the limb.
struct GoesProjection: Projectable {
    static let height = 35786023.0
    static let equatorialRadius = 6378137.0
    static let polarRadius = 6356752.31414
    static let longitude = -75.0

    func forward(latitude: Float, longitude: Float) -> (x: Float, y: Float) {
        let a = Self.equatorialRadius, b = Self.polarRadius, h = Self.height + a
        let lat = Double(latitude) * .pi / 180
        let lon = (Double(longitude) - Self.longitude) * .pi / 180
        let geocentric = atan(b * b / (a * a) * tan(lat))
        let radius = b / sqrt(1 - (1 - b * b / (a * a)) * pow(cos(geocentric), 2))
        let earthX = radius * cos(geocentric) * cos(lon)
        let earthY = radius * cos(geocentric) * sin(lon)
        let earthZ = radius * sin(geocentric)
        let sx = h - earthX
        guard h * earthX >= earthY * earthY + a * a / (b * b) * earthZ * earthZ + earthX * earthX else {
            return (.nan, .nan)
        }
        let distance = sqrt(sx * sx + earthY * earthY + earthZ * earthZ)
        return (Float(asin(earthY / distance) * Self.height), Float(atan2(earthZ, sx) * Self.height))
    }

    func inverse(x: Float, y: Float) -> (latitude: Float, longitude: Float) {
        let x = Double(x) / Self.height, y = Double(y) / Self.height
        let a = Self.equatorialRadius, b = Self.polarRadius, h = Self.height + a
        let ratio = a * a / (b * b)
        let qa = pow(sin(x), 2) + pow(cos(x), 2) * (pow(cos(y), 2) + ratio * pow(sin(y), 2))
        let qb = -2 * h * cos(x) * cos(y)
        let discriminant = qb * qb - 4 * qa * (h * h - a * a)
        guard discriminant >= 0 else { return (.nan, .nan) }
        let rs = (-qb - sqrt(discriminant)) / (2 * qa)
        let sx = rs * cos(x) * cos(y), sy = -rs * sin(x), sz = rs * cos(x) * sin(y)
        return (Float(atan(ratio * sz / hypot(h - sx, sy)) * 180 / .pi),
                Float(Self.longitude - atan2(sy, h - sx) * 180 / .pi))
    }

    func crsWkt2(latMin: Float, lonMin: Float, latMax: Float, lonMax: Float) -> String {
        // The rectangular grid corners are in space, so do not use their NaN coordinates for BBOX.
        return """
        PROJCRS["GOES-19 ABI fixed grid",BASEGEOGCRS["GRS 1980",DATUM["GRS 1980",ELLIPSOID["GRS 1980",6378137,298.2572221]]],CONVERSION["GOES-East",METHOD["Geostationary Satellite (Sweep X)"],PARAMETER["Longitude of natural origin",-75],PARAMETER["Satellite Height",35786023],PARAMETER["False easting",0],PARAMETER["False northing",0]],CS[Cartesian,2],AXIS["easting",east],AXIS["northing",north],LENGTHUNIT["metre",1]]
        """
    }
}
