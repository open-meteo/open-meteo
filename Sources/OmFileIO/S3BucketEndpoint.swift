import Foundation
import Vapor

public struct S3BucketEndpoint: Sendable, Hashable, CustomStringConvertible {
    /// URL with credentials `https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket/`
    private let rawEndpoint: String
    
    /// Profile string like `aws` or `ceph`
    public let profile: String?

    public init(rawEndpoint: String, profile: String?) {
        self.rawEndpoint = rawEndpoint
        self.profile = profile
    }

    public var description: String {
        rawEndpoint.stripHttpPassword()
    }

    public var uploadServer: String {
        rawEndpoint
    }

    public var isDefaultOpenMeteoOrAws: Bool {
        return (rawEndpoint == "openmeteo" && profile == nil) || profile == "aws"
    }

    public func uploadURL(remotePath: String) -> String {
        return rawEndpoint.s3UploadUrlPrefix + remotePath
    }

    public static func parseList(_ buckets: String) -> [S3BucketEndpoint] {
        return buckets.split(separator: ",").map { bucket in
            let bucketSplit = bucket.split(separator: "@")
            if bucketSplit.count == 3 {
                // http://user:pw@something.com/@profile
                let url = bucketSplit[0] + "@" + bucketSplit[1]
                guard url.starts(with: "s3://") else {
                    fatalError("S3 bucket URL must start with 's3://'")
                }
                guard url.hasSuffix("/") else {
                    fatalError("S3 bucket URL must end with '/")
                }
                return S3BucketEndpoint(rawEndpoint: bucketSplit[0] + "@" + bucketSplit[1], profile: String(bucketSplit[2]))
            }
            let bucketName = bucketSplit[0]
            let profile = bucketSplit.count > 1 ? String(bucketSplit[1]) : nil
            let profileUpper = profile.map { "_\($0.uppercased())" } ?? ""

            // An environment variable may overwrite the S3 credentials
            if let credentials = Environment.get("S3_CREDENTIALS_\(bucketName.uppercased())\(profileUpper)") {
                // URL stored in Env variable S3_CREDENTIALS_BUCKETNAME_PROFILE
                guard credentials.starts(with: "s3://") else {
                    fatalError("S3 bucket URL must start with 's3://'")
                }
                guard credentials.hasSuffix("/") else {
                    fatalError("S3 bucket URL must end with '/")
                }
                return S3BucketEndpoint(rawEndpoint: credentials, profile: profile)
            }
            guard bucket.starts(with: "s3://") else {
                fatalError("S3 bucket URL must start with 's3://'")
            }
            guard bucket.hasSuffix("/") else {
                fatalError("S3 bucket URL must end with '/")
            }
            return S3BucketEndpoint(rawEndpoint: String(bucket), profile: nil)
        }
    }
    
    public static func loadFromEnvironment(variable: String) -> [S3BucketEndpoint] {
        guard let configured = Environment.get(variable) else {
            return []
        }
        return self.parseList(configured)
    }
}

public struct S3BucketEndpointList: Sendable, Sequence, CustomStringConvertible {
    private let endpoints: [S3BucketEndpoint]

    public init(_ buckets: String) {
        self.endpoints = S3BucketEndpoint.parseList(buckets)
    }

    public var description: String {
        return endpoints.map { $0.description }.joined(separator: ",")
    }

    public func makeIterator() -> Array<S3BucketEndpoint>.Iterator {
        return endpoints.makeIterator()
    }
}

extension String {
    public var s3UploadUrlPrefix: String {
        let withSlash = hasSuffix("/") ? self : self + "/"
        if withSlash.starts(with: "s3://") || withSlash.starts(with: "http://") || withSlash.starts(with: "https://") {
            return withSlash
        }
        return "s3://\(withSlash)"
    }

    var asUrlGetQueryForLogging: Substring {
        guard let schemaIndex = firstRange(of: "://"),
              let queryStart = self[schemaIndex.upperBound...].firstIndex(of: "/") else {
            return Substring(self)
        }
        return self[queryStart...]
    }
}
