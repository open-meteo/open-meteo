import OmFileFormat

extension OmFileChunkLayout.Chunk {
    /// Visit spatial cells in row-major order, stopping at the first match.
    /// The predicate receives a global grid cell index: y * fullGridWidth + x.
    /// All other dimensions (such as time or ensemble member) are ignored.
    /// The axes must be distinct valid dimensions, and the grid cell count
    /// must fit in Int. Pass nil for yDimension for flat [location, time]
    /// arrays; xDimension then identifies the location axis and its coordinates
    /// are passed directly to the predicate as grid cell indices.
    public func containsCell(
        yDimension: Int?,
        xDimension: Int,
        where predicate: (_ gridcell: Int) throws -> Bool
    ) rethrows -> Bool {
        precondition(arrayDimensions.indices.contains(xDimension))
        let width = arrayDimensions[xDimension]
        let rows: Range<UInt64>
        if let yDimension {
            precondition(arrayDimensions.indices.contains(yDimension) && yDimension != xDimension)
            precondition(arrayDimensions[yDimension] <= UInt64(Int.max) / width, "Grid cell count is out of bounds")
            rows = range(in: yDimension)
        } else {
            precondition(width <= UInt64(Int.max), "Grid cell count is out of bounds")
            rows = 0..<1
        }
        for y in rows {
            let row = y * width
            for x in range(in: xDimension) {
                if try predicate(Int(row + x)) {
                    return true
                }
            }
        }
        return false
    }
}
