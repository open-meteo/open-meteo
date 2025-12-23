import OrderedCollections

public enum CfGridMappingName: String, Codable, Sendable {
    case lambertConformalConic = "lambert_conformal_conic"
    case lambertAzimuthalEqualArea = "lambert_azimuthal_equal_area"
    case stereographic = "stereographic"
    case rotatedLatLon = "rotated_latitude_longitude"
    case latitudeLongitude = "latitude_longitude"

    var proj4Name: String {
        switch self {
        case .lambertConformalConic:
            return "lcc"
        case .lambertAzimuthalEqualArea:
            return "laea"
        case .stereographic:
            return "stere"
        case .rotatedLatLon:
            // This is a tiny hack to correctly support rotated lat/lon grids
            // They are generally defined as a oblique spherical projection,
            // where the projection to be used needs to be specified via the
            // +o_proj parameter. There is no real equivalent to the o_proj
            // parameter in the CF conventions.
            // https://proj.org/en/stable/operations/projections/ob_tran.html
            // https://cfconventions.org/cf-conventions/cf-conventions.html#_rotated_pole
            return "ob_tran +o_proj=longlat"
        case .latitudeLongitude:
            return "longlat"
        }
    }
}

// CF Convention attribute names enumeration
public enum CfGridMappingAttributeName: String, CaseIterable, Codable, Sendable {
    case latitudeOfProjectionOrigin = "latitude_of_projection_origin"
    case longitudeOfProjectionOrigin = "longitude_of_projection_origin"
    case longitudeOfCentralMeridian = "longitude_of_central_meridian"
    case straightVerticalLongitudeFromPole = "straight_vertical_longitude_from_pole"
    case standardParallel = "standard_parallel"
    // case standardParallel2 = "standard_parallel_2"
    case falseEasting = "false_easting"
    case falseNorthing = "false_northing"
    case earthRadius = "earth_radius"
    // case scaleFactorAtProjectionOrigin = "scale_factor_at_projection_origin"
    case gridNorthPoleLatitude = "grid_north_pole_latitude"
    case gridNorthPoleLongitude = "grid_north_pole_longitude"
    case northPoleGridLongitude = "north_pole_grid_longitude"

    // Type-safe mapping from CF attributes to proj4 parameters
    var proj4Parameter: Proj4Parameter {
        switch self {
        case .latitudeOfProjectionOrigin: return .lat0
        case .longitudeOfProjectionOrigin: return .lon0
        case .longitudeOfCentralMeridian: return .lon0
        case .straightVerticalLongitudeFromPole: return .lon0
        case .standardParallel: return .lat1
        // case .standardParallel2: return .lat2
        case .falseEasting: return .x0
        case .falseNorthing: return .y0
        case .earthRadius: return .R
        // case .scaleFactorAtProjectionOrigin: return .k0
        case .gridNorthPoleLatitude: return .oLatP
        case .gridNorthPoleLongitude: return .oLonP
        case .northPoleGridLongitude: return .lon1
        }
    }
}

// Proj4 parameter names enumeration
enum Proj4Parameter: String, CaseIterable {
    case lat0 = "lat_0"
    case lon0 = "lon_0"
    case lat1 = "lat_1"
    case lat2 = "lat_2"
    case x0 = "x_0"
    case y0 = "y_0"
    case k0 = "k_0"
    case R = "R"
    case oLatP = "o_lat_p"
    case oLonP = "o_lon_p"
    case lon1 = "lon_1"
}


/// Grid mapping name according to CF conventions
/// https://cfconventions.org/cf-conventions/cf-conventions.html#appendix-grid-mappings
public protocol CfProjectionConvertible: Sendable {
    var gridMappingName: CfGridMappingName { get }
    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float>

    // Default implementation provided in extension
    func toProj4String() -> String
}

extension CfProjectionConvertible {
    func toProj4String() -> String {
        let cfAttributes = toCfAttributes()
        var proj4String = "+proj=\(gridMappingName.proj4Name)"

        // Map CF attributes to proj4 parameters using type-safe enums
        cfAttributes.forEach { cfKey, value in
            proj4String += " +\(cfKey.proj4Parameter.rawValue)=\(value)"
        }

        // Add default attributes
        proj4String += " +units=m +datum=WGS84 +no_defs +type=crs"

        return proj4String
    }
}

// Lambert Conformal Conic projection parameters
struct LambertConformalConicParameters: CfProjectionConvertible {
    let standardParallel: Float // FIXME: Can be 1 or 2 values ???
    let longitudeOfCentralMeridian: Float
    let latitudeOfProjectionOrigin: Float
    let falseEasting: Float?
    let falseNorthing: Float?
    let earthRadius: Float?

    var gridMappingName: CfGridMappingName { .lambertConformalConic }

    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float> {
        var attributes: OrderedDictionary<CfGridMappingAttributeName, Float> = [:]

        // if standardParallel.count >= 1 {
        //     attributes[.standardParallel] = standardParallel[0]
        // }
        // if standardParallel.count >= 2 {
        //     attributes[.standardParallel2] = standardParallel[1]
        // }
        attributes[.standardParallel] = standardParallel

        attributes[.latitudeOfProjectionOrigin] = latitudeOfProjectionOrigin
        attributes[.longitudeOfCentralMeridian] = longitudeOfCentralMeridian

        if let falseEasting = falseEasting {
            attributes[.falseEasting] = falseEasting
        }
        if let falseNorthing = falseNorthing {
            attributes[.falseNorthing] = falseNorthing
        }
        if let earthRadius = earthRadius {
            attributes[.earthRadius] = earthRadius
        }

        return attributes
    }
}

// Lambert Azimuthal Equal Area
struct LambertAzimuthalEqualAreaParameters: CfProjectionConvertible {
    let longitudeOfProjectionOrigin: Float
    let latitudeOfProjectionOrigin: Float
    let falseEasting: Float?
    let falseNorthing: Float?
    let earthRadius: Float?

    var gridMappingName: CfGridMappingName { .lambertAzimuthalEqualArea }

    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float> {
        var attributes: OrderedDictionary<CfGridMappingAttributeName, Float> = [:]

        attributes[.longitudeOfProjectionOrigin] = longitudeOfProjectionOrigin
        attributes[.latitudeOfProjectionOrigin] = latitudeOfProjectionOrigin

        if let falseEasting = falseEasting {
            attributes[.falseEasting] = falseEasting
        }
        if let falseNorthing = falseNorthing {
            attributes[.falseNorthing] = falseNorthing
        }
        if let earthRadius = earthRadius {
            attributes[.earthRadius] = earthRadius
        }

        return attributes
    }
}

// Stereographic projection
struct StereographicParameters: CfProjectionConvertible {
    let straightVerticalLongitudeFromPole: Float
    let latitudeOfProjectionOrigin: Float
    let earthRadius: Float?

    var gridMappingName: CfGridMappingName { .stereographic }

    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float> {
        var attributes: OrderedDictionary<CfGridMappingAttributeName, Float> = [:]

        attributes[.latitudeOfProjectionOrigin] = latitudeOfProjectionOrigin
        attributes[.straightVerticalLongitudeFromPole] = straightVerticalLongitudeFromPole

        if let earthRadius = earthRadius {
            attributes[.earthRadius] = earthRadius
        }

        return attributes
    }
}

// Rotated Latitude-Longitude
struct RotatedLatitudeLongitudeParameters: CfProjectionConvertible {
    let gridNorthPoleLatitude: Float
    let gridNorthPoleLongitude: Float
    let northPoleGridLongitude: Float?

    var gridMappingName: CfGridMappingName { .rotatedLatLon }

    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float> {
        var attributes: OrderedDictionary<CfGridMappingAttributeName, Float> = [:]

        attributes[.gridNorthPoleLatitude] = gridNorthPoleLatitude
        attributes[.gridNorthPoleLongitude] = gridNorthPoleLongitude

        if let northPoleGridLongitude = northPoleGridLongitude {
            attributes[.northPoleGridLongitude] = northPoleGridLongitude
        }

        return attributes
    }
}

// Regular Latitude-Longitude (no projection)
struct LatitudeLongitudeParameters: CfProjectionConvertible {
    var gridMappingName: CfGridMappingName { .latitudeLongitude }

    func toCfAttributes() -> OrderedDictionary<CfGridMappingAttributeName, Float> {
        // No additional parameters needed for regular lat/lon
        return [:]
    }
}
