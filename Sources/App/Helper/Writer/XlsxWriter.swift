import Foundation
import Vapor


extension ForecastapiResultSet {
    func toXlsxResponse(timestamp: Timestamp) throws -> Response {
        let multiLocation = results.count > 1
        if results.count > 100 {
            throw ForecastapiError.generic(message: "XLSX supports only up to 100 locations")
        }
        
        let sheet = try XlsxWriter()
        sheet.startRow()
        if multiLocation {
            sheet.write("location_id")
        }
        sheet.write("latitude")
        sheet.write("longitude")
        sheet.write("elevation")
        sheet.write("utc_offset_seconds")
        sheet.write("timezone")
        sheet.write("timezone_abbreviation")
        sheet.endRow()
        
        for (i, location) in results.enumerated() {
            sheet.startRow()
            if multiLocation {
                sheet.write(i+1)
            }
            sheet.write(location.latitude)
            sheet.write(location.longitude)
            sheet.write(location.elevation ?? .nan)
            sheet.write(location.utc_offset_seconds)
            sheet.write(location.timezone.identifier)
            sheet.write(location.timezone.abbreviation)
            sheet.endRow()
        }
        
        for (i, location) in results.enumerated() {
            if let current_weather = try location.current_weather?() {
                if i == 0 {
                    sheet.startRow()
                    sheet.endRow()
                    sheet.startRow()
                    if multiLocation {
                        sheet.write("location_id")
                    }
                    sheet.write("current_weather_time")
                    sheet.write("temperature (\(current_weather.temperature_unit.abbreviation))")
                    sheet.write("windspeed (\(current_weather.windspeed_unit.abbreviation))")
                    sheet.write("winddirection (\(current_weather.winddirection_unit.abbreviation))")
                    sheet.write("weathercode (\(current_weather.weathercode_unit.abbreviation))")
                    sheet.write("is_day")
                    sheet.endRow()
                }
                
                sheet.startRow()
                if multiLocation {
                    sheet.write(i+1)
                }
                sheet.writeTimestamp(current_weather.time.add(location.utc_offset_seconds))
                sheet.write(current_weather.temperature)
                sheet.write(current_weather.windspeed)
                sheet.write(current_weather.winddirection)
                sheet.write(current_weather.weathercode)
                sheet.write(current_weather.is_day)
                sheet.endRow()
            }
        }
        
        for (i, location) in results.enumerated() {
            try location.current?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
        }
        for (i, location) in results.enumerated() {
            try location.minutely15?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
        }
        for (i, location) in results.enumerated() {
            try location.hourly?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
        }
        for (i, location) in results.enumerated() {
            try location.sixHourly?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
        }
        for (i, location) in results.enumerated() {
            try location.daily?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? i : nil)
        }
        
        let data = sheet.write(timestamp: timestamp)
        let response = Response(body: .init(buffer: data))
        response.headers.replaceOrAdd(name: .contentType, value: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(results.first?.formatedCoordinatesFilename ?? "").xlsx\"")
        return response
    }
}

extension ApiSection {
    fileprivate func writeXlsx(into sheet: XlsxWriter, utc_offset_seconds: Int, location_id: Int?) throws {
        if location_id == nil || location_id == 0 {
            sheet.startRow()
            sheet.endRow()
            sheet.startRow()
            if location_id != nil {
                sheet.write("location_id")
            }
            sheet.write("time")
            for e in columns {
                sheet.write("\(e.variable) (\(e.unit.abbreviation))")
            }
            sheet.endRow()
        }

        for (i, time) in time.enumerated() {
            sheet.startRow()
            if let location_id {
                sheet.write(location_id + 1)
            }
            sheet.writeTimestamp(time.add(utc_offset_seconds))
            for e in columns {
                switch e.data {
                case .float(let a):
                    sheet.write(a[i])
                case .timestamp(let a):
                    sheet.writeTimestamp(a[i].add(utc_offset_seconds))
                }
            }
            sheet.endRow()
        }
    }
}

extension ApiSectionSingle {
    fileprivate func writeXlsx(into sheet: XlsxWriter, utc_offset_seconds: Int, location_id: Int?) throws {
        if location_id == nil || location_id == 0 {
            sheet.startRow()
            sheet.endRow()
            sheet.startRow()
            if location_id != nil {
                sheet.write("location_id")
            }
            sheet.write("time")
            for e in columns {
                sheet.write("\(e.variable) (\(e.unit.abbreviation))")
            }
            sheet.endRow()
        }

        sheet.startRow()
        if let location_id {
            sheet.write(location_id + 1)
        }
        sheet.writeTimestamp(time.add(utc_offset_seconds))
        for e in columns {
            sheet.write(e.value)
        }
        sheet.endRow()
    }
}
