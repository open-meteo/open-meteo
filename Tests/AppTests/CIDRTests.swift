import Testing
@testable import App

@Suite("CIDR Parsing and Containment")
struct CIDRTests {
    
    @Test("Test CIDR Array")
    func cidrArray() throws {
        let a = CIDR.parseIPv4("192.168.10.5")!.mappedToV6
        let b = CIDR.parseIPv6("::ffff:192.168.10.5")!
        #expect(a == b)
        let c = CIDR.parseIPv6("::ffff:192.168.10.1")!
        
        #expect(c.ipv6InPrefix(other: a, prefixLength: 24) == true)
        print(c.__u6_addr.__u6_addr8, a.__u6_addr.__u6_addr8)
        #expect(c.ipv6InPrefix(other: a, prefixLength: 96+32) == false)
        
        let cidr = CIDR("192.168.0.0/16,2001:db8::/32,203.0.113.5/32,1501:db8::1/128,198.51.100.7,1001:db8::42")
        #expect(cidr.contains("192.168.10.5"))
        #expect(!cidr.contains("192.169.0.1"))
        #expect(cidr.contains("::ffff:192.168.10.5")) // ipv4 mapping
        #expect(!cidr.contains("::ffff:192.169.0.1")) // ipv4 mapping
        #expect(cidr.contains("203.0.113.5"))
        #expect(!cidr.contains("203.0.113.6"))
        #expect(cidr.contains("2001:db8::1"))
        #expect(!cidr.contains("2001:dead::1"))
        #expect(cidr.contains("1501:db8::1"))
        #expect(!cidr.contains("1501:db8::2"))
        #expect(cidr.contains("198.51.100.7"))
        #expect(!cidr.contains("198.51.100.8"))
        #expect(cidr.contains("1001:db8::42"))
        #expect(!cidr.contains("1001:db8::43"))
    }
}

