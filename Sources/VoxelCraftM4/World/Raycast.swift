import Foundation
import simd

struct RaycastHit {
    let blockX: Int
    let blockY: Int
    let blockZ: Int
    let normal: SIMD3<Int>   // Face normal (the side that was hit) — used for placement
    let block: BlockType
}

enum Raycast {
    /// DDA voxel raycast. Returns hit info or nil if nothing solid found within `maxDistance`.
    static func cast(origin: Float3, direction: Float3, maxDistance: Float, world: World) -> RaycastHit? {
        let dir = normalize(direction)
        var x = Int(floor(origin.x))
        var y = Int(floor(origin.y))
        var z = Int(floor(origin.z))

        let stepX = dir.x > 0 ? 1 : -1
        let stepY = dir.y > 0 ? 1 : -1
        let stepZ = dir.z > 0 ? 1 : -1

        let invDx = abs(dir.x) < 1e-6 ? Float.infinity : 1.0 / abs(dir.x)
        let invDy = abs(dir.y) < 1e-6 ? Float.infinity : 1.0 / abs(dir.y)
        let invDz = abs(dir.z) < 1e-6 ? Float.infinity : 1.0 / abs(dir.z)

        // Distance to next voxel boundary along each axis
        var tMaxX: Float = {
            let fx = origin.x - floor(origin.x)
            return (dir.x > 0 ? (1.0 - fx) : fx) * invDx
        }()
        var tMaxY: Float = {
            let fy = origin.y - floor(origin.y)
            return (dir.y > 0 ? (1.0 - fy) : fy) * invDy
        }()
        var tMaxZ: Float = {
            let fz = origin.z - floor(origin.z)
            return (dir.z > 0 ? (1.0 - fz) : fz) * invDz
        }()

        var lastNormal = SIMD3<Int>(0, 0, 0)

        while true {
            let block = world.blockAt(x, y, z)
            if block.isSolid {
                return RaycastHit(blockX: x, blockY: y, blockZ: z, normal: lastNormal, block: block)
            }

            // Step to next voxel
            if tMaxX < tMaxY && tMaxX < tMaxZ {
                if tMaxX > maxDistance { return nil }
                x += stepX
                tMaxX += invDx
                lastNormal = SIMD3<Int>(-stepX, 0, 0)
            } else if tMaxY < tMaxZ {
                if tMaxY > maxDistance { return nil }
                y += stepY
                tMaxY += invDy
                lastNormal = SIMD3<Int>(0, -stepY, 0)
            } else {
                if tMaxZ > maxDistance { return nil }
                z += stepZ
                tMaxZ += invDz
                lastNormal = SIMD3<Int>(0, 0, -stepZ)
            }
        }
    }
}