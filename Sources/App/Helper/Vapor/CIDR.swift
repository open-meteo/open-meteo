// Provides CIDR parsing and containment checks for IPv4 and IPv6 using POSIX inet_pton

import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Array of CIDR v6 networks and prefix lengths, including IPv4 mapped to IPv6. Optimised for linear memory
public struct CIDR: Equatable {
    let ips: [in6_addr]
    let prefix: [UInt8]
    
    func contains(_ v6: in6_addr) -> Bool {
        return zip(ips, prefix).contains(where: {
            $0.ipv6InPrefix(other: v6, prefixLength: $1)
        })
    }
    
    func contains(_ ip: String) -> Bool {
        if let ip = Self.parseIPv4(ip) {
            return contains(ip.mappedToV6)
        }
        guard let ip = Self.parseIPv6(ip) else { return false }
        return contains(ip)
    }
    
    public init(filename: String) throws {
        let content = try String(contentsOfFile: filename, encoding: .utf8)
        self.init(content)
    }
    
    /// Accept CSV encoded CIDR networks. Ignore invalid entries
    public init(_ string: String) {
        var ipv6 = [in6_addr]()
        var ipv6Prefix = [UInt8]()
        for string in string.components(separatedBy: ",") {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            // If there is a slash, parse as CIDR with explicit prefix
            guard let slashIndex = trimmed.firstIndex(of: "/") else  {
                // No slash: accept a single IP address as a host with full-length prefix
                if let v4int = Self.parseIPv4(trimmed) {
                    ipv6.append(v4int.mappedToV6)
                    ipv6Prefix.append(128)
                    continue
                } else if let v6addr = Self.parseIPv6(trimmed) {
                    ipv6.append(v6addr)
                    ipv6Prefix.append(128)
                    continue
                } else {
                    continue
                }
            }
            let addr = String(trimmed[..<slashIndex])
            let prefixStr = String(trimmed[trimmed.index(after: slashIndex)...])
            guard let p = UInt8(prefixStr) else {
                continue
            }
            if let v4int = Self.parseIPv4(addr) {
                guard (0...32).contains(p) else {
                    continue
                }
                // Map IPv4 prefix to IPv6 prefix by adding 96
                ipv6.append(v4int.mappedToV6)
                ipv6Prefix.append(96 + p)
            } else if let v6addr = Self.parseIPv6(addr) {
                guard (0...128).contains(p) else {
                    continue
                }
                ipv6.append(v6addr)
                ipv6Prefix.append(p)
            }
        }
        self.ips = ipv6
        self.prefix = ipv6Prefix
    }
}

extension CIDR {
    static func parseIPv4(_ string: String) -> in_addr? {
        var addr = in_addr()
        let res = string.withCString { cs in inet_pton(AF_INET, cs, &addr) }
        if res == 1 {
            return addr
        }
        return nil
    }

    static func parseIPv6(_ string: String) -> in6_addr? {
        var addr = in6_addr()
        let res = string.withCString { cs in inet_pton(AF_INET6, cs, &addr) }
        if res == 1 {
            return addr
        }
        return nil
    }
}

extension in6_addr: @retroactive Equatable {
    public static func == (lhs: in6_addr, rhs: in6_addr) -> Bool {
        // Compare the raw bytes
        return withUnsafeBytes(of: lhs) { lhsBytes in
            withUnsafeBytes(of: rhs) { rhsBytes in
                lhsBytes.elementsEqual(rhsBytes)
            }
        }
    }
}


extension in6_addr {
    func ipv6InPrefix(other: in6_addr, prefixLength: UInt8) -> Bool {
        guard (0...128).contains(prefixLength) else { return false }

        let fullBytes = Int(prefixLength) / 8
        let remainingBits = Int(prefixLength) % 8

        return withUnsafeBytes(of: self) { ipBytes in
            withUnsafeBytes(of: other) { netBytes in

                // Compare full bytes in one shot
                if let ipBytes = ipBytes.baseAddress,
                    let netBytes = netBytes.baseAddress,
                    fullBytes > 0 &&
                    memcmp(ipBytes, netBytes, Int(fullBytes)) != 0 {
                    return false
                }

                // No partial byte → exact match so far
                if remainingBits == 0 {
                    return true
                }

                // Mask the next byte
                let mask: UInt8 = 0xFF << (8 - remainingBits)

                return (ipBytes[fullBytes] & mask) ==
                       (netBytes[fullBytes] & mask)
            }
        }
    }
}

extension in_addr {
    var mappedToV6: in6_addr {
        var ipv6 = in6_addr()
        withUnsafeBytes(of: self) { v4bytes in
            withUnsafeMutableBytes(of: &ipv6) { v6bytes in
                // ::ffff:0:0/96 prefix
                v6bytes[10] = 0xff
                v6bytes[11] = 0xff

                // copy IPv4 into last 4 bytes
                v6bytes[12] = v4bytes[0]
                v6bytes[13] = v4bytes[1]
                v6bytes[14] = v4bytes[2]
                v6bytes[15] = v4bytes[3]
            }
        }
        return ipv6
    }
}
