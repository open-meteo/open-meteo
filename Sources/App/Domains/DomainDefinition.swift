/// Storage metadata shared by static datasets and weather domains.
protocol DatasetDefinition: Sendable {
    /// Dataset name used as its storage directory.
    var domainRegistry: DomainRegistry { get }

    /// Additional storage owner whose static files are required by this dataset.
    var staticFileDependency: DomainRegistry? { get }
}

extension DatasetDefinition {
    var staticFileDependency: DomainRegistry? { nil }

    /// Temporary directory used by the dataset's downloader.
    var downloadDirectory: String {
        "\(OpenMeteo.tempDirectory)download-\(domainRegistry.rawValue)/"
    }
}

/// Time-series metadata and grid loading for weather domains.
protocol DomainDefinition: DatasetDefinition {
    /// Complete grid identity, including its static fields.
    var gridRegistry: GridRegistry { get }

    /// Time resolution in seconds: 3600 for hourly, 10800 for 3-hourly
    var dtSeconds: Int { get }

    /// How often a domain is updated in seconds. `3600` for updates every hour
    var updateIntervalSeconds: Int { get }

    /// If present, the timerange that is available in a master file
    var masterTimeRange: Range<Timestamp>? { get }

    /// The time length of each compressed time series file
    var omFileLength: Int { get }

    /// Number of ensemble members, including control. Default 1
    var countEnsembleMember: Int { get }

    /// Whether or not to generate the full run database in ./data_run
    var generateFullRun: Bool { get }

    /// Whether to generate regular database ./data
    var generateTimeSeries: Bool { get }

    /// Resolves a domain whose grid is ready for synchronous reader operations.
    func loadDomain() async throws -> any GenericDomain
}

extension DomainDefinition {
    var staticFileDependency: DomainRegistry? {
        guard let owner = gridRegistry.staticDomain, owner != domainRegistry else {
            return nil
        }
        return owner
    }
}
