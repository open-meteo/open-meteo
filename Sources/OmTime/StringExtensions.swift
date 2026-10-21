public extension String {
    /// Assuming the string contains to 2 integers split by a dash like `0-10`, return both numbers
    func splitTo2Integer() -> (Int, Int)? {
        let splited = split(separator: "-")
        guard
            splited.count == 2,
            let left = Int(splited[0]),
            let right = Int(splited[1])
        else {
            return nil
        }
        return (left, right)
    }

    /// Convert to `Int` if possible
    func toInt() -> Int? {
        return Int(self)
    }

    /// Convert to `Timestamp` if possible
    func toTimestamp() -> Timestamp? {
        guard let timeIntervalSince1970 = toInt() else {
            return nil
        }
        return Timestamp(timeIntervalSince1970)
    }
}

public extension StringProtocol {
    subscript(_ range: Range<Int>) -> Self.SubSequence {
        let start = index(startIndex, offsetBy: Swift.max(0, range.lowerBound))
        let end = index(start, offsetBy: Swift.min(count - range.lowerBound, range.upperBound - range.lowerBound))
        return self[start..<end]
    }
    
    subscript(_ range: CountablePartialRangeFrom<Int>) -> Self.SubSequence {
        let start = index(startIndex, offsetBy: Swift.max(0, range.lowerBound))
         return self[start...]
    }
}
