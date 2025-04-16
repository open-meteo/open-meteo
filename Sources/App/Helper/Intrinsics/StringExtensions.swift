extension String {
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
}
