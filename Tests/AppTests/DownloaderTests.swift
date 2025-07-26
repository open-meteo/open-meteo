@testable import App
import Testing
import AsyncHTTPClient

@Suite struct DownloaderTests {
    @Test func testAwsSign() async throws {
        let url = "https://examplebucket.s3.amazonaws.com/test.txt"
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Range", value: "bytes=0-9")
        //request.headers.add(name: "Content-Type", value: "text/plain")
        //request.body = .bytes(ByteBuffer(string: "Hello AWS!"))

        let signer = AWSSigner(accessKey: "AKIAIOSFODNN7EXAMPLE", secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", region: "us-east-1", service: "s3")

        let signingKey = signer.getSignatureKey(date: "20151229")
        #expect(signingKey.hex == "cbcef1ebeaefc82cce6530b9f0a9ae598846065f5c5bae0674bd5ebc4ba52d28")

        try signer.sign(request: &request, body: nil, now: .init("2013-05-24T00:00:00Z", strategy: .iso8601))

        #expect(request.headers.first(name: "Authorization") == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")

        //let response = try await app!.http.client.shared.execute(request, timeout: .seconds(10))
        //print(response.status)
        //print(try await response.body.collect(upTo: 10000).readStringImmutable()!)
    }
}
