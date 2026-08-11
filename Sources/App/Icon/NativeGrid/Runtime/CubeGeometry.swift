import Foundation

extension IconNativeGrid {
    /// Pure cube-map geometry shared by artifact generation and runtime search.
    enum CubeGeometry {
        struct Location: Sendable {
            let face: Int
            let u: Double
            let v: Double
            let normalizedNormalComponentSquared: Double
            let x: Int
            let y: Int
        }

        struct Node: Sendable {
            var face: Int
            var level: Int
            var x: Int
            var y: Int

            static let empty = Self(face: 0, level: 0, x: 0, y: 0)
        }

        @inline(__always)
        static func location(
            for point: IconNativeCenter,
            resolution: Int,
            resolutionScale: Double? = nil
        ) -> Location {
            let projected = project(point)
            let scale = resolutionScale ?? Double(resolution) * 0.5
            let x = min(resolution - 1, max(0, Int((projected.u + 1) * scale)))
            let y = min(resolution - 1, max(0, Int((projected.v + 1) * scale)))
            let normalComponent: Double
            switch projected.face {
            case 0, 1: normalComponent = abs(point.x)
            case 2, 3: normalComponent = abs(point.y)
            default: normalComponent = abs(point.z)
            }
            let normSquared = point.dot(point)
            let inverseNormSquared = 1 / normSquared
            return Location(
                face: projected.face,
                u: projected.u,
                v: projected.v,
                normalizedNormalComponentSquared: normalComponent * normalComponent
                    * inverseNormSquared,
                x: x,
                y: y
            )
        }

        /// The normalized cube projection is 1-Lipschitz because every unnormalized face vector has
        /// length at least one. Every point in the node is therefore within `sqrt(2) / 2^level` chord
        /// distance of its centre. The triangle inequality supplies an exact conservative prune.
        @inline(__always)
        static func nodeCannotImprove(
            _ node: Node,
            query: IconNativeCenter,
            maximumCandidateDistance: Double
        ) -> Bool {
            let scale = Double(1 << node.level)
            let u = -1 + (Double(node.x) + 0.5) * 2 / scale
            let v = -1 + (Double(node.y) + 0.5) * 2 / scale
            let center = faceVector(face: node.face, u: u, v: v)
            let centerDistanceSquared = max(0, 2 - 2 * query.dot(center))
            let maximumDistance = maximumCandidateDistance + sqrt(2.0) / scale + 1e-14
            return centerDistanceSquared > maximumDistance * maximumDistance
        }

        @inline(__always)
        private static func project(
            _ point: IconNativeCenter
        ) -> (face: Int, u: Double, v: Double) {
            let ax = abs(point.x)
            let ay = abs(point.y)
            let az = abs(point.z)
            if ax >= ay, ax >= az {
                let inverse = 1 / ax
                if point.x >= 0 { return (0, point.y * inverse, point.z * inverse) }
                return (1, -point.y * inverse, point.z * inverse)
            }
            if ay >= az {
                let inverse = 1 / ay
                if point.y >= 0 { return (2, -point.x * inverse, point.z * inverse) }
                return (3, point.x * inverse, point.z * inverse)
            }
            let inverse = 1 / az
            if point.z >= 0 { return (4, point.y * inverse, -point.x * inverse) }
            return (5, point.y * inverse, point.x * inverse)
        }

        @inline(__always)
        static func faceVector(
            face: Int,
            u: Double,
            v: Double
        ) -> IconNativeCenter {
            let raw: IconNativeCenter
            switch face {
            case 0: raw = IconNativeCenter(x: 1, y: u, z: v)
            case 1: raw = IconNativeCenter(x: -1, y: -u, z: v)
            case 2: raw = IconNativeCenter(x: -u, y: 1, z: v)
            case 3: raw = IconNativeCenter(x: u, y: -1, z: v)
            case 4: raw = IconNativeCenter(x: -v, y: u, z: 1)
            default: raw = IconNativeCenter(x: v, y: u, z: -1)
            }
            let inverseLength = 1 / sqrt(raw.dot(raw))
            return IconNativeCenter(
                x: raw.x * inverseLength,
                y: raw.y * inverseLength,
                z: raw.z * inverseLength
            )
        }
    }
}
