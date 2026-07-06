import Foundation
import Vapor

struct S3BucketEndpoint: Sendable, Hashable, CustomStringConvertible {
    /// URL with credentials `https://S3-access-key:S3-secret-key@s3-host.tld/some-bucket`
    private let rawEndpoint: String
    
    /// Profile string like `aws` or `ceph`
    let profile: String?

    init(rawEndpoint: String, profile: String?) {
        self.rawEndpoint = rawEndpoint
        self.profile = profile
    }

    var description: String {
        rawEndpoint.stripHttpPassword()
    }

    var uploadServer: String {
        rawEndpoint
    }

    var isDefaultOpenMeteoOrAws: Bool {
        return (rawEndpoint == "openmeteo" && profile == nil) || profile == "aws"
    }

    func uploadURL(remotePath: String) -> String {
        return rawEndpoint.s3UploadUrlPrefix + remotePath
    }

    static func parseList(_ buckets: String) -> [S3BucketEndpoint] {
        return buckets.split(separator: ",").map { bucket in
            let bucketSplit = bucket.split(separator: "@")
            if bucketSplit.count == 3 {
                // http://user:pw@something.com/@profile
                return S3BucketEndpoint(rawEndpoint: bucketSplit[0] + "@" + bucketSplit[1], profile: String(bucketSplit[2]))
            }
            let bucket = bucketSplit[0]
            let profile = bucketSplit.count > 1 ? String(bucketSplit[1]) : nil
            let profileUpper = profile.map { "_\($0.uppercased())" } ?? ""

            // An environment variable may overwrite the S3 credentials
            if let credentials = Environment.get("S3_CREDENTIALS_\(bucket.uppercased())\(profileUpper)") {
                return S3BucketEndpoint(rawEndpoint: credentials, profile: profile)
            }

            return S3BucketEndpoint(rawEndpoint: String(bucket), profile: profile)
        }
    }
}

struct S3BucketEndpointList: Sendable, Sequence, CustomStringConvertible {
    private let endpoints: [S3BucketEndpoint]

    init(_ buckets: String, domain: DomainRegistry) {
        self.endpoints = S3BucketEndpoint.parseList(buckets)
    }

    var description: String {
        return endpoints.map { $0.description }.joined(separator: ",")
    }

    func makeIterator() -> Array<S3BucketEndpoint>.Iterator {
        return endpoints.makeIterator()
    }
}

extension String {
    var s3UploadUrlPrefix: String {
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
