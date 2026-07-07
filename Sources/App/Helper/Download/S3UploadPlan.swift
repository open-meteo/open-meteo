import Foundation
import NIOCore

struct S3UploadTarget: Sendable, Equatable {
    let bucketEndpoint: S3BucketEndpoint
    let localFile: String
    let remotePath: String
    let contentType: String

    func uploadURL() -> String {
        return bucketEndpoint.uploadURL(remotePath: remotePath)
    }

    var logLocation: Substring {
        return uploadURL().asUrlGetQueryForLogging
    }
}

enum S3UploadFileKind: Sendable {
    case regular
    case previousDay
    case rolling
    case spatial
}

enum S3UploadOperation: Sendable {
    case multipart(S3UploadTarget)
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
        endpoints: S3BucketEndpointList,
        artifact: S3UploadArtifact
    ) -> [S3UploadOperation] {
        return targets(endpoints: endpoints, artifact: artifact).map { target in
            switch artifact {
            case .timeSeries, .fullRun, .spatialFile:
                return .multipart(target)
            case .modelMeta(_, let data), .fullRunMeta(_, let data), .spatialMeta(_, _, _, let data):
                return .metadataAfterCommits(target, data)
            }
        }
    }

    static func targets(endpoints: S3BucketEndpointList, artifact: S3UploadArtifact) -> [S3UploadTarget] {
        let plan = artifact.plan
        return targets(
            domain: plan.domain,
            endpoints: endpoints,
            localFile: plan.localFile,
            remotePath: plan.remotePath,
            kind: plan.kind,
            contentType: plan.contentType
        )
    }

    static func targets(
        domain: DomainRegistry,
        endpoints: S3BucketEndpointList,
        localFile: String,
        remotePath: String,
        kind: S3UploadFileKind = .regular,
        contentType: String = "application/octet-stream"
    ) -> [S3UploadTarget] {
        return endpoints.compactMap { endpoint in
            guard shouldUpload(domain: domain, endpoint: endpoint, kind: kind) else {
                return nil
            }
            return target(endpoint: endpoint, localFile: localFile, remotePath: remotePath, contentType: contentType)
        }
    }

    static func shouldUpload(domain: DomainRegistry, endpoint: S3BucketEndpoint, kind: S3UploadFileKind) -> Bool {
        switch kind {
        case .regular:
            return true
        case .previousDay:
            return !endpoint.isDefaultOpenMeteoOrAws
        case .rolling:
            return domain == .google_weathernext2_ensemble && !endpoint.isDefaultOpenMeteoOrAws
        case .spatial:
            return endpoint.profile != "ceph"
        }
    }

    private static func target(endpoint: S3BucketEndpoint, localFile: String, remotePath: String, contentType: String) -> S3UploadTarget {
        return S3UploadTarget(
            bucketEndpoint: endpoint,
            localFile: localFile,
            remotePath: remotePath,
            contentType: contentType
        )
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
