// Provides CIDR parsing and containment checks for IPv4 and IPv6 using Network framework

import Foundation
import Network


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
            guard let ip = IPv4Address(v4) else {
                return false
            }
            return contains(ip.asUInt32)
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
            guard let ip = IPv6Address(v6) else {
                return false
            }
            return contains(ip.asUInt32Quad)
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
            // If there is a slash, parse as CIDR with explicit prefix
            guard let slashIndex = string.firstIndex(of: "/") else  {
                // No slash: accept a single IP address as a host with full-length prefix
                if let v4int = IPv4Address(string) {
                    ipv4.append(v4int.asUInt32)
                    ipv4Prefix.append(32)
                    continue
                } else if let v6addr = IPv6Address(string) {
                    ipv6.append(v6addr.asUInt32Quad)
                    ipv6Prefix.append(128)
                    continue
                } else {
                    continue
                }
            }
            let addr = String(string[..<slashIndex])
            let prefixStr = String(string[string.index(after: slashIndex)...])
            guard let p = UInt8(prefixStr) else {
                continue
            }
            // IPv4
            if let v4int = IPv4Address(addr) {
                guard (0...32).contains(p) else {
                    continue
                }
                ipv4.append(v4int.asUInt32)
                ipv4Prefix.append(p)
            } else if let v6addr = IPv6Address(addr) {
                guard (0...128).contains(p) else {
                    continue
                }
                ipv6.append(v6addr.asUInt32Quad)
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


extension IPv4Address {
    fileprivate var asUInt32: CIDR.IPv4 {
        let ip = rawValue.withUnsafeBytes({
            $0.load(as: UInt32.self).bigEndian
        })
        return CIDR.IPv4(ip: ip)
    }
}

extension IPv6Address {
    fileprivate var asUInt32Quad: CIDR.IPv6 {
        return rawValue.withUnsafeBytes { ptr in
            let w0 = ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian
            let w1 = ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            let w2 = ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian
            let w3 = ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian
            return CIDR.IPv6(w0: w0, w1: w1, w2: w2, w3: w3)
        }
    }
}
