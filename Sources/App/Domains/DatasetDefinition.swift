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
