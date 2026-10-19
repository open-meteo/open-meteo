/// Define functions to download surface and pressure level variables for ICON
protocol IconVariableDownloadable: DwdVariableDownloadable, Hashable {
}

extension IconSurfaceVariable: IconVariableDownloadable {
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .temperature_80m, .temperature_120m, .temperature_180m, .soil_temperature_0cm, .soil_temperature_6cm, .soil_temperature_18cm, .soil_temperature_54cm:
            return (1, -273.15) // Temperature is stored in kelvin. Convert to celsius
        case .pressure_msl:
            return (1 / 100, 0) // convert to hPa
        case .soil_moisture_0_to_1cm:
            return (0.001 / 0.01, 0) // 1cm depth
        case .soil_moisture_1_to_3cm:
            return (0.001 / 0.02, 0) // 2cm depth
        case .soil_moisture_3_to_9cm:
            return (0.001 / 0.06, 0) // 6cm depth
        case .soil_moisture_9_to_27cm:
            return (0.001 / 0.18, 0) // 18cm depth
        case .soil_moisture_27_to_81cm:
            return (0.001 / 0.54, 0) // 54cm depth
        default:
            return nil
        }
    }

    func correctDownloadedValues(data: inout [Float]) {
        switch self {
        case .direct_radiation, .diffuse_radiation:
            for i in data.indices {
                data[i] = max(data[i], 0)
            }
        case .convective_inhibition:
            for i in data.indices {
                if data[i] <= -999 {
                    data[i] = 0
                }
            }
        default:
            break
        }
    }
}

extension IconPressureVariable: IconVariableDownloadable {
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        case.geopotential_height:
            // convert geopotential to height (WMO defined gravity constant)
            return (1 / 9.80665, 0)
        default:
            return nil
        }
    }

}
