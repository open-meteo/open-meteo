import Testing
@testable import OmFileIO


@Suite struct S3TimeTests {
    @Test func s3XmlDate() throws {
        let date = try "2026-08-19T09:38:57.123Z".parseXmlS3Date()
        #expect(date.iso8601_YYYY_MM_dd_HH_mm_ss == "2026-08-19T09:38:57")
    }
    
    @Test func lastHttpModifiedDate() throws {
        let a = try "Wed, 19 Aug 2026 19:38:12 GMT".parseLastModifiedDate()
        #expect(a.iso8601_YYYY_MM_dd_HH_mm_ss == "2026-08-19T19:38:12")
        #expect(a.lastModifiedHttpDateFormat == "Wed, 19 Aug 2026 19:38:12 GMT")
    }
}
