

public extension Timestamp {
    func toComponents() -> IsoDate {
        IsoDate(timeIntervalSince1970: timeIntervalSince1970)
    }

    func toIsoDateTime() -> IsoDateTime {
        IsoDateTime(timeIntervalSince1970: timeIntervalSince1970)
    }

    func with(year: Int? = nil, month: Int? = nil, day: Int? = nil) -> Timestamp {
        let date = toComponents()
        return Timestamp(year ?? date.year, month ?? date.month, day ?? date.day)
    }

}
