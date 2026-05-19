import Foundation

extension Sequence {
    /// Group the sequence by the given criterion.
    /// - Parameter criterion: The basis by which to group the sequence.
    /// - Throws: `Error`.
    /// - Returns: Array of `(key: Group, values: [Element])`
    func groupedPreservedOrder<Group: Equatable>(
        by criterion: (_ transforming: Element) throws -> Group
    ) rethrows -> [(key: Group, values: [Element])] {
        var groups = [(key: Group, values: [Element])]()
        for element in self {
            let key = try criterion(_: element)
            if let keyIndex = groups.firstIndex(where: { $0.key == key }) {
                groups[keyIndex] = (key, groups[keyIndex].values + [element])
            } else {
                groups.append((key: key, values: [element]))
            }
        }
        return groups
    }

    /// Group the sequence by the given criterion.
    /// 
    /// This Hashable version avoids O(N^2) runtime for large sequences!
    /// - Parameter criterion: The basis by which to group the sequence.
    /// - Throws: `Error`.
    /// - Returns: Array of `(key: Group, values: [Element])`
    /// TODO: Potentially this should be merged with the above version, using the equatable version for small sequences and the hashable version for large sequences.
    func groupedPreservedOrder<Group: Hashable>(
        by criterion: (Element) throws -> Group
    ) rethrows -> [(key: Group, values: [Element])] {
        var groupIndex: [AnyHashable: Int] = [:]
        var groupValues: [[Element]] = []
        var keyOrder: [AnyHashable] = []

        for element in self {
            let key = try criterion(element)
            let anyKey = AnyHashable(key)

            if let existingIndex = groupIndex[anyKey] {
                groupValues[existingIndex].append(element)
            } else {
                let newIndex = groupValues.count
                groupIndex[anyKey] = newIndex
                keyOrder.append(anyKey)
                groupValues.append([element])
            }
        }

        return keyOrder.enumerated().map { (key: $0.element.base as! Group, values: groupValues[$0.offset]) }
    }
}
