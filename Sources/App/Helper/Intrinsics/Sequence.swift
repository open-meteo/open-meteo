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
    func groupedPreservedOrder<Group: Hashable>(
        by criterion: (Element) throws -> Group
    ) rethrows -> [(key: Group, values: [Element])] {
        var groupIndex: [Group: Int] = [:]
        var groups: [(key: Group, values: [Element])] = []

        for element in self {
            let key = try criterion(element)
            if let existingIndex = groupIndex[key] {
                groups[existingIndex].values.append(element)
            } else {
                groupIndex[key] = groups.count
                groups.append((key: key, values: [element]))
            }
        }

        return groups
    }
}
