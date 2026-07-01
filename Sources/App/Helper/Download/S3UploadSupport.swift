import Foundation
import Vapor

struct S3BucketEndpoint: Sendable, Equatable {
    let bucket: String
    let profile: String?

    static func parseList(_ buckets: String, domain: DomainRegistry) -> [S3BucketEndpoint] {
        return buckets.split(separator: ",").map { bucket in
            let bucketSplit = bucket.split(separator: "@")
            if bucketSplit.count == 3 {
                // http://user:pw@something.com/@profile
                return S3BucketEndpoint(bucket: bucketSplit[0] + "@" + bucketSplit[1], profile: String(bucketSplit[2]))
            }
            let bucket = String(bucketSplit[0].replacing("MODEL", with: domain.bucketName))
            let profile = bucketSplit.count > 1 ? String(bucketSplit[1]) : nil
            let profileUpper = profile.map { "_\($0.uppercased())" } ?? ""

            // An environment variable may overwrite the S3 credentials
            if let credentials = Environment.get("S3_CREDENTIALS_\(bucket.uppercased())\(profileUpper)") {
                return S3BucketEndpoint(bucket: credentials, profile: profile)
            }

            return S3BucketEndpoint(bucket: bucket, profile: profile)
        }
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
