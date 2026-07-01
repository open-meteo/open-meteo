import Foundation
import NIOCore

struct S3UploadTarget: Sendable, Equatable {
    let bucketEndpoint: String
    let localFile: String
    let url: String
    let contentType: String
}

enum S3UploadFileKind: Sendable {
    case regular
    case previousDay
    case rolling
    case spatial
}

enum S3UploadOperation: Sendable {
    case multipart(S3UploadTarget)
    case syncBeforeMetadata(S3UploadSyncTarget)
    case metadataAfterCommits(S3UploadTarget, ByteBufferView)
}

enum S3UploadArtifact {
    case timeSeries(OmFileType)
    case fullRun(OmFileType)
    case modelMeta(ModelUpdateMetaFile, data: ByteBufferView)
    case fullRunMeta(FullRunMetaFile, data: ByteBufferView)
    case spatialFile(
        domain: DomainRegistry,
        localFile: String,
        run: Timestamp,
        time: Timestamp,
        realm: String?
    )
    case spatialMeta(
        domain: DomainRegistry,
        localFile: String,
        remote: S3SpatialMetaFile,
        data: ByteBufferView
    )
}

enum S3SpatialMetaFile {
    case run(run: Timestamp, realm: String?)
    case inProgress(realm: String?)
    case latest(realm: String?)
}

enum S3UploadPlan {
    static func operations(
        buckets: String,
        artifact: S3UploadArtifact
    ) -> [S3UploadOperation] {
        return targets(buckets: buckets, artifact: artifact).map { target in
            switch artifact {
            case .timeSeries, .fullRun, .spatialFile:
                return .multipart(target)
            case .modelMeta(_, let data), .fullRunMeta(_, let data), .spatialMeta(_, _, _, let data):
                return .metadataAfterCommits(target, data)
            }
        }
    }

    static func targets(buckets: String, artifact: S3UploadArtifact) -> [S3UploadTarget] {
        let plan = artifact.plan
        return targets(
            domain: plan.domain,
            buckets: buckets,
            localFile: plan.localFile,
            remotePath: plan.remotePath,
            kind: plan.kind,
            contentType: plan.contentType
        )
    }

    static func targets(
        domain: DomainRegistry,
        buckets: String,
        localFile: String,
        remotePath: String,
        kind: S3UploadFileKind = .regular,
        contentType: String = "application/octet-stream"
    ) -> [S3UploadTarget] {
        return S3BucketEndpoint.parseList(buckets, domain: domain).compactMap { endpoint in
            guard shouldUpload(domain: domain, bucket: endpoint.bucket, profile: endpoint.profile, kind: kind) else {
                return nil
            }
            return target(bucket: endpoint.bucket, localFile: localFile, remotePath: remotePath, contentType: contentType)
        }
    }

    static func shouldUpload(domain: DomainRegistry, bucket: String, profile: String?, kind: S3UploadFileKind) -> Bool {
        switch kind {
        case .regular:
            return true
        case .previousDay:
            return !isDefaultOpenMeteoOrAws(bucket: bucket, profile: profile)
        case .rolling:
            return domain == .google_weathernext2_ensemble && !isDefaultOpenMeteoOrAws(bucket: bucket, profile: profile)
        case .spatial:
            return profile != "ceph"
        }
    }

    static func spatialSyncTargets(
        buckets: String,
        domain: DomainRegistry,
        localDirectory: String
    ) -> [S3UploadSyncTarget] {
        return S3BucketEndpoint.parseList(buckets, domain: domain).compactMap { endpoint in
            guard shouldUpload(domain: domain, bucket: endpoint.bucket, profile: endpoint.profile, kind: .spatial) else {
                return nil
            }
            return S3UploadSyncTarget(
                bucketEndpoint: endpoint.bucket,
                localDirectory: localDirectory,
                server: endpoint.bucket,
                basePath: "data_spatial/\(domain.rawValue)/"
            )
        }
    }

    static func staticSyncTargets(
        buckets: String,
        domain: DomainRegistry
    ) -> [S3UploadSyncTarget] {
        return S3BucketEndpoint.parseList(buckets, domain: domain).map { endpoint in
            S3UploadSyncTarget(
                bucketEndpoint: endpoint.bucket,
                localDirectory: "\(domain.directory)static",
                server: endpoint.bucket,
                basePath: "data/\(domain.rawValue)/static",
                exclude: [".*", "*~", "meta.json"]
            )
        }
    }

    private static func isDefaultOpenMeteoOrAws(bucket: String, profile: String?) -> Bool {
        return (bucket == "openmeteo" && profile == nil) || profile == "aws"
    }

    private static func target(bucket: String, localFile: String, remotePath: String, contentType: String) -> S3UploadTarget {
        return S3UploadTarget(
            bucketEndpoint: bucket,
            localFile: localFile,
            url: bucket.s3UploadUrlPrefix + remotePath,
            contentType: contentType
        )
    }
}

struct S3UploadSyncTarget: Sendable, Equatable {
    let bucketEndpoint: String
    let localDirectory: String
    let server: String
    let basePath: String
    let exclude: [String]

    init(
        bucketEndpoint: String,
        localDirectory: String,
        server: String,
        basePath: String,
        exclude: [String] = [".*", "*~"]
    ) {
        self.bucketEndpoint = bucketEndpoint
        self.localDirectory = localDirectory
        self.server = server
        self.basePath = basePath
        self.exclude = exclude
    }
}

private extension S3UploadArtifact {
    var plan: (domain: DomainRegistry, localFile: String, remotePath: String, kind: S3UploadFileKind, contentType: String) {
        switch self {
        case .timeSeries(let file):
            return (
                file.domainRegistry,
                file.getFilePath(),
                "data/\(file.getRelativeFilePath())",
                file.s3UploadKind,
                "application/octet-stream"
            )
        case .fullRun(let file):
            return (
                file.domainRegistry,
                file.getFilePath(),
                "data_run/\(file.getRelativeFilePath())",
                .regular,
                "application/octet-stream"
            )
        case .modelMeta(let file, _):
            return (
                file.domain,
                file.getFilePath(),
                "data/\(file.domain.rawValue)/static/meta.json",
                .regular,
                "application/json"
            )
        case .fullRunMeta(let file, _):
            let remotePath: String
            let domain: DomainRegistry
            switch file {
            case .run(let fileDomain, let run):
                domain = fileDomain
                remotePath = "data_run/\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/meta.json"
            case .latest(let fileDomain):
                domain = fileDomain
                remotePath = "data_run/\(domain.rawValue)/latest.json"
            }
            return (domain, file.getFilePath(), remotePath, .regular, "application/json")
        case .spatialFile(let domain, let localFile, let run, let time, let realm):
            let remotePath = "data_spatial/\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/\(time.iso8601_YYYY_MM_dd_HHmm)\(realm.s3UploadSuffix).om"
            return (
                domain,
                localFile,
                remotePath,
                .spatial,
                "application/octet-stream"
            )
        case .spatialMeta(let domain, let localFile, let remote, _):
            return (
                domain,
                localFile,
                "data_spatial/\(domain.rawValue)/\(remote.relativePath)",
                .spatial,
                "application/json"
            )
        }
    }
}

private extension S3SpatialMetaFile {
    var relativePath: String {
        switch self {
        case .run(let run, let realm):
            return "\(run.format_directoriesYYYYMMddhhmm)/meta\(realm.s3UploadSuffix).json"
        case .inProgress(let realm):
            return "in-progress\(realm.s3UploadSuffix).json"
        case .latest(let realm):
            return "latest\(realm.s3UploadSuffix).json"
        }
    }
}

private extension Optional where Wrapped == String {
    var s3UploadSuffix: String {
        return map { "_\($0)" } ?? ""
    }
}

private extension OmFileType {
    var domainRegistry: DomainRegistry {
        switch self {
        case .domainChunk(let domain, _, _, _, _, _),
                .staticFile(let domain, _, _),
                .run(let domain, _, _):
            return domain
        }
    }

    var s3UploadKind: S3UploadFileKind {
        switch self {
        case .domainChunk(_, _, .rolling, _, _, _):
            return .rolling
        case .domainChunk(_, _, _, _, _, let previousDay) where previousDay > 0:
            return .previousDay
        case .domainChunk, .staticFile, .run:
            return .regular
        }
    }
}
