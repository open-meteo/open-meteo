extension InlineArray {
    /// Return a mutable pointer. This is deliberately leaking the internal pointer.
    mutating func veryUnsafeMutablePointer() -> UnsafeMutableBufferPointer<Element> {
        withUnsafeMutableBytes(of: &self, {$0.assumingMemoryBound(to: Element.self)})
    }
}
