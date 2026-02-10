import Testing
@testable import App

@Suite("CIDR Parsing and Containment")
struct CIDRTests {
    
    @Test("Test CIDR Array")
    func cidrArray() throws {
        let cidr = CIDR("192.168.0.0/16,2001:db8::/32,203.0.113.5/32,1501:db8::1/128,198.51.100.7,1001:db8::42")
        #expect(cidr.ipv4.contains("192.168.10.5"))
        #expect(!cidr.ipv4.contains("192.169.0.1"))
        #expect(cidr.ipv4.contains("203.0.113.5"))
        #expect(!cidr.ipv4.contains("203.0.113.6"))
        #expect(cidr.ipv6.contains("2001:db8::1"))
        #expect(!cidr.ipv6.contains("2001:dead::1"))
        #expect(cidr.ipv6.contains("1501:db8::1"))
        #expect(!cidr.ipv6.contains("1501:db8::2"))
        #expect(cidr.ipv4.contains("198.51.100.7"))
        #expect(!cidr.ipv4.contains("198.51.100.8"))
        #expect(cidr.ipv6.contains("1001:db8::42"))
        #expect(!cidr.ipv6.contains("1001:db8::43"))
    }
}

