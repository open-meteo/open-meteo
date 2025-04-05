import Foundation
import Vapor


extension ForecastapiResult {
    func toXlsxResponse(timestamp: Timestamp) throws -> Response {
        let multiLocation = results.count > 1
        
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
        
        for location in results {
            sheet.startRow()
            guard let first = location.results.first else {
                continue
            }
            if multiLocation {
                sheet.write(location.locationId)
            }
            sheet.write(first.latitude, significantDigits: 4)
            sheet.write(first.longitude, significantDigits: 4)
            sheet.write(first.elevation ?? .nan, significantDigits: 0)
            sheet.write(location.utc_offset_seconds)
            sheet.write(location.timezone.identifier)
            sheet.write(location.timezone.abbreviation)
            sheet.endRow()
        }
        for location in results {
            try location.current?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? location.locationId : nil)
        }
        for location in results {
            try location.minutely15?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? location.locationId : nil)
        }
        for location in results {
            try location.hourly?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? location.locationId : nil)
        }
        for location in results {
            try location.sixHourly?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? location.locationId : nil)
        }
        for location in results {
            try location.daily?().writeXlsx(into: sheet, utc_offset_seconds: location.utc_offset_seconds, location_id: multiLocation ? location.locationId : nil)
        }
        
        let data = sheet.write(timestamp: timestamp)
        let response = Response(body: .init(buffer: data))
        response.headers.replaceOrAdd(name: .contentType, value: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"open-meteo-\(results.first?.results.first?.formatedCoordinatesFilename ?? "").xlsx\"")
        return response

    }
}

extension ApiSectionString {
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
                sheet.write(location_id)
            }
            sheet.writeTimestamp(time.add(utc_offset_seconds))
            for e in columns {
                switch e.data {
                case .float(let a):
                    sheet.write(a[i], significantDigits: e.unit.significantDigits)
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
            sheet.write(location_id)
        }
        sheet.writeTimestamp(time.add(utc_offset_seconds))
        for e in columns {
            sheet.write(e.value, significantDigits: e.unit.significantDigits)
        }
        sheet.endRow()
    }
}
