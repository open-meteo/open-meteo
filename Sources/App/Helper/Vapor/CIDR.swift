// Provides CIDR parsing and containment checks for IPv4 and IPv6 using POSIX inet_pton

import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif


/// Array of CIDR v4 and v6 networks and prefix lengths. Optimised for linear memory
public struct CIDR: Equatable {
    let ipv4: V4Array
    let ipv6: V6Array
    
    public struct V4Array: Equatable {
        let ips: [CIDR.IPv4]
        let prefix: [UInt8]
        
        func contains(_ v4: CIDR.IPv4) -> Bool {
            return zip(ips, prefix).contains(where: {
                $0.contains(other: v4, prefix: $1)
            })
        }
        
        func contains(_ v4: String) -> Bool {
            guard let ip = parseIPv4(v4) else { return false }
            return contains(ip)
        }
    }
    
    public struct V6Array: Equatable {
        let ips: [CIDR.IPv6]
        let prefix: [UInt8]
        
        func contains(_ v6: CIDR.IPv6) -> Bool {
            return zip(ips, prefix).contains(where: {
                $0.contains(other: v6, prefix: $1)
            })
        }
        
        func contains(_ v6: String) -> Bool {
            guard let ip = parseIPv6(v6) else { return false }
            return contains(ip)
        }
    }
    
    public init(filename: String) throws {
        let content = try String(contentsOfFile: filename, encoding: .utf8)
        self.init(content)
    }
    
    /// Accept CSV encoded CIDR networks. Ignore invalid entries
    public init(_ string: String) {
        var ipv4 = [CIDR.IPv4]()
        var ipv4Prefix = [UInt8]()
        var ipv6 = [CIDR.IPv6]()
        var ipv6Prefix = [UInt8]()
        for string in string.components(separatedBy: ",") {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            // If there is a slash, parse as CIDR with explicit prefix
            guard let slashIndex = trimmed.firstIndex(of: "/") else  {
                // No slash: accept a single IP address as a host with full-length prefix
                if let v4int = parseIPv4(trimmed) {
                    ipv4.append(v4int)
                    ipv4Prefix.append(32)
                    continue
                } else if let v6addr = parseIPv6(trimmed) {
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
            // IPv4
            if let v4int = parseIPv4(addr) {
                guard (0...32).contains(p) else {
                    continue
                }
                ipv4.append(v4int)
                ipv4Prefix.append(p)
            } else if let v6addr = parseIPv6(addr) {
                guard (0...128).contains(p) else {
                    continue
                }
                ipv6.append(v6addr)
                ipv6Prefix.append(p)
            }
        }
        self.ipv4 = .init(ips: ipv4, prefix: ipv4Prefix)
        self.ipv6 = .init(ips: ipv6, prefix: ipv6Prefix)
    }
}

extension CIDR {
    public struct IPv6: Equatable {
        // Use four 32-bit words for IPv6 representation to simplify bit masking
        let w0: UInt32
        let w1: UInt32
        let w2: UInt32
        let w3: UInt32
        
        func contains(other: Self, prefix: UInt8) -> Bool {
            if prefix == 0 { return true }
            if prefix >= 128 { return self == other }
            // How many full 32-bit words are covered
            let fullWords = Int(prefix / 32)
            let remBits = Int(prefix % 32)
            // Compare full words without allocating
            switch fullWords {
            case 0:
                break
            case 1:
                if w0 != other.w0 { return false }
            case 2:
                if w0 != other.w0 || w1 != other.w1 { return false }
            case 3:
                if w0 != other.w0 || w1 != other.w1 || w2 != other.w2 { return false }
            default:
                // fullWords >= 4
                return true
            }
            if remBits == 0 { return true }
            // Apply mask to the next word
            let nextWordIndex = fullWords
            let mask: UInt32 = remBits == 32 ? ~UInt32(0) : (~UInt32(0) << (32 - remBits))
            switch nextWordIndex {
            case 0:
                return (w0 & mask) == (other.w0 & mask)
            case 1:
                return (w1 & mask) == (other.w1 & mask)
            case 2:
                return (w2 & mask) == (other.w2 & mask)
            case 3:
                return (w3 & mask) == (other.w3 & mask)
            default:
                return true
            }
        }
    }
    
    public struct IPv4: Equatable {
        let ip: UInt32
        
        func contains(other: Self, prefix: UInt8) -> Bool {
            if prefix <= 0 { return true }
            if prefix >= 32 { return self == other }
            let mask: UInt32 = prefix == 0 ? 0 : (~UInt32(0) << (32 - prefix))
            return (self.ip & mask) == (other.ip & mask)
        }
    }
}


fileprivate func parseIPv4(_ string: String) -> CIDR.IPv4? {
    var addr = in_addr()
    let res = string.withCString { cs in inet_pton(AF_INET, cs, &addr) }
    if res == 1 {
        // inet_pton stores in network byte order (big endian)
        return CIDR.IPv4(ip: UInt32(addr.s_addr).bigEndian)
    }
    return nil
}

fileprivate func parseIPv6(_ string: String) -> CIDR.IPv6? {
    var addr = in6_addr()
    let res = string.withCString { cs in inet_pton(AF_INET6, cs, &addr) }
    if res == 1 {
        // Extract four 32-bit big-endian words from the 16-byte IPv6 address
        return withUnsafeBytes(of: addr) { rawPtr -> CIDR.IPv6 in
            let bytes = rawPtr.bindMemory(to: UInt8.self)
            let w0 = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            let w1 = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
            let w2 = (UInt32(bytes[8]) << 24) | (UInt32(bytes[9]) << 16) | (UInt32(bytes[10]) << 8) | UInt32(bytes[11])
            let w3 = (UInt32(bytes[12]) << 24) | (UInt32(bytes[13]) << 16) | (UInt32(bytes[14]) << 8) | UInt32(bytes[15])
            return CIDR.IPv6(w0: w0, w1: w1, w2: w2, w3: w3)
        }
    }
    return nil
}
