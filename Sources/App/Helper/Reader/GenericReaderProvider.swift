/// Can generate a reader with an associated domain -> Could be simplified later once all controller use a comon class to pass variables instead of more protocols
protocol GenericReaderProvider {
    associatedtype DomainProvider: GenericDomainProvider

    init?(domain: DomainProvider, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws

    init?(domain: DomainProvider, gridpoint: Int, options: GenericReaderOptions) async throws
}

extension GenericReaderProvider {
    /// Prepare readers for Point, MultiPoint and BoundingBox queries
    public static func prepareReaders(domains: [DomainProvider], params: ApiQueryParameter, options: GenericReaderOptions, currentTime: Timestamp, forecastDayDefault: Int, forecastDaysMax: Int, pastDaysMax: Int, allowedRange: Range<Timestamp>) async throws -> [(locationId: Int, timezone: TimezoneWithOffset, time: ForecastApiTimeRange, perModel: [(domain: DomainProvider, reader: () async throws -> (Self?))])] {
        let prepared = try await params.prepareCoordinates(allowTimezones: true, logger: options.logger, httpClient: options.httpClient)

        switch prepared {
        case .coordinates(let coordinates):
            return try await coordinates.asyncMap { prepared in
                let coordinates = prepared.coordinate
                let timezone = prepared.timezone
                let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: prepared.startEndDate, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                return (coordinates.locationId, timezone, time, await domains.asyncCompactMap { domain in
                    return (domain, {
                        return try await Self(domain: domain, lat: coordinates.latitude, lon: coordinates.longitude, elevation: coordinates.elevation, mode: params.cell_selection ?? .land, options: options)
                    })
                })
            }
        case .boundingBox(let bbox, dates: let dates, timezone: let timezone):
            return try await domains.asyncFlatMap({ domain in
                guard let grid = domain.genericDomain?.grid else {
                    throw ForecastapiError.generic(message: "Bounding box calls not supported for domain \(domain)")
                }
                guard let gridpoionts = grid.findBox(boundingBox: bbox) else {
                    throw ForecastapiError.generic(message: "Bounding box calls not supported for grid of domain \(domain)")
                }

                if dates.count == 0 {
                    let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: nil, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                    var locationId = -1
                    return await gridpoionts.asyncMap( { gridpoint in
                        locationId += 1
                        return (locationId, timezone, time, [(domain, { () -> Self? in
                            guard let reader = try await Self(domain: domain, gridpoint: gridpoint, options: options) else {
                                return nil
                            }
                            return reader
                        })])
                    })
                }

                return try await dates.asyncFlatMap({ date -> [(Int, TimezoneWithOffset, ForecastApiTimeRange, [(DomainProvider, () async throws -> Self?)])] in
                    let time = try params.getTimerange2(timezone: timezone, current: currentTime, forecastDaysDefault: forecastDayDefault, forecastDaysMax: forecastDaysMax, startEndDate: date, allowedRange: allowedRange, pastDaysMax: pastDaysMax)
                    var locationId = -1
                    return await gridpoionts.asyncMap( { gridpoint in
                        locationId += 1
                        return (locationId, timezone, time, [(domain, { () -> Self? in
                            guard let reader = try await Self(domain: domain, gridpoint: gridpoint, options: options) else {
                                return nil
                            }
                            return reader
                        })])
                    })
                })
            })
        }
    }
}

protocol GenericDomainProvider {
    var genericDomain: GenericDomain? { get }
}

extension GenericDomain where Self: GenericDomainProvider {
    var genericDomain: GenericDomain? { self }
}
