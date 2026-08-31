import OmTime

extension StringProtocol {
    func parseXmlS3Date() throws -> Timestamp {
        guard count == 24 else { throw TimeError.InvalidDateFromat }
        guard let year = Int(self[0..<4]), (1900...2200).contains(year),
              let month = Int(self[5..<7]), (1...12).contains(month),
              let day = Int(self[8..<10]), (1...31).contains(day),
              let hour = Int(self[11..<13]), (0...23).contains(hour),
              let minute = Int(self[14..<16]), (0...59).contains(minute),
              let second = Int(self[17..<19]), (0...59).contains(second)
        else {
            throw TimeError.InvalidDate
        }
        return Timestamp(year, month, day, hour, minute, second)
    }
}
