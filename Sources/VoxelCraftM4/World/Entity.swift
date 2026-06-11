import Foundation
import simd

/// Simple cuboid mob (a Minecraft-style cow).
/// Built from cubes: body, head, 4 legs, with 2 colors (white + black spots / brown).
final class Cow {
    var position: Float3
    var yaw: Float = 0
    var velocity: Float3 = Float3(0, 0, 0)

    /// AI: pick a random walk direction and walk for a few seconds, then pause.
    var stateTimer: Float = 0
    var walking: Bool = false

    init(position: Float3) {
        self.position = position
        self.yaw = Float.random(in: 0..<(2 * .pi))
    }

    func update(dt: Float, world: World) {
        stateTimer -= dt
        if stateTimer <= 0 {
            walking.toggle()
            stateTimer = Float.random(in: 1.5...4.0)
            if walking {
                yaw = Float.random(in: 0..<(2 * .pi))
            }
        }

        if walking {
            let dir = Float3(sin(yaw), 0, -cos(yaw))
            position += dir * 1.2 * dt   // slow walk
        }

        // Apply gravity / snap to ground using world heightmap (sample block below)
        let bx = Int(floor(position.x))
        let bz = Int(floor(position.z))
        // Find ground from current y downward
        var by = Int(floor(position.y))
        while by > 0 && !world.blockAt(bx, by - 1, bz).isSolid {
            by -= 1
        }
        // Snap if close
        let groundY = Float(by)
        if abs(position.y - groundY) < 6 {
            position.y = groundY
        }
    }

    /// Append vertices for this cow into a vertex array.
    /// Cow is composed of cubes: body (W=1.6, H=1.0, D=0.7), head (0.6 cube), 4 legs (0.25 x 0.6 x 0.25)
    func appendMesh(into verts: inout [Vertex]) {
        let cosY = cos(yaw), sinY = sin(yaw)

        // local -> world transform
        func place(localCenter: Float3, size: Float3, color: Float3, headColor: Bool = false) {
            // Rotate local around Y, translate to position
            let lx = localCenter.x
            let lz = localCenter.z
            let wx = position.x + (lx * cosY - lz * sinY)
            let wz = position.z + (lx * sinY + lz * cosY)
            let wy = position.y + localCenter.y

            // Build axis-aligned cube facing yaw direction (we approximate by AABB at center)
            // (For simplicity we draw axis-aligned cubes — looks fine for Minecraft cubes)
            let h = size * 0.5
            let p000 = Float3(wx - h.x, wy - h.y, wz - h.z)
            let p100 = Float3(wx + h.x, wy - h.y, wz - h.z)
            let p010 = Float3(wx - h.x, wy + h.y, wz - h.z)
            let p110 = Float3(wx + h.x, wy + h.y, wz - h.z)
            let p001 = Float3(wx - h.x, wy - h.y, wz + h.z)
            let p101 = Float3(wx + h.x, wy - h.y, wz + h.z)
            let p011 = Float3(wx - h.x, wy + h.y, wz + h.z)
            let p111 = Float3(wx + h.x, wy + h.y, wz + h.z)

            func quad(_ a: Float3, _ b: Float3, _ c: Float3, _ d: Float3, _ n: Float3) {
                verts.append(Vertex(position: a, normal: n, color: color))
                verts.append(Vertex(position: b, normal: n, color: color))
                verts.append(Vertex(position: c, normal: n, color: color))
                verts.append(Vertex(position: a, normal: n, color: color))
                verts.append(Vertex(position: c, normal: n, color: color))
                verts.append(Vertex(position: d, normal: n, color: color))
            }
            quad(p100, p101, p111, p110, Float3( 1,  0,  0))
            quad(p001, p000, p010, p011, Float3(-1,  0,  0))
            quad(p010, p110, p111, p011, Float3( 0,  1,  0))
            quad(p000, p001, p101, p100, Float3( 0, -1,  0))
            quad(p101, p001, p011, p111, Float3( 0,  0,  1))
            quad(p000, p100, p110, p010, Float3( 0,  0, -1))
        }

        let bodyColor = Float3(0.95, 0.95, 0.92)   // off-white
        let spotColor = Float3(0.20, 0.20, 0.18)   // black
        let hornColor = Float3(0.90, 0.85, 0.75)

        // Body — center at origin, length along local Z (we’ll use Z as front-back)
        place(localCenter: Float3(0, 1.0, 0), size: Float3(0.7, 0.8, 1.4), color: bodyColor)

        // Head — front of body
        place(localCenter: Float3(0, 1.2, -1.0), size: Float3(0.6, 0.6, 0.5), color: bodyColor)

        // Snout (smaller, darker)
        place(localCenter: Float3(0, 1.05, -1.32), size: Float3(0.35, 0.3, 0.2), color: Float3(0.85, 0.78, 0.70))

        // Horns (tiny dark cubes)
        place(localCenter: Float3(-0.22, 1.55, -0.95), size: Float3(0.08, 0.18, 0.08), color: hornColor)
        place(localCenter: Float3( 0.22, 1.55, -0.95), size: Float3(0.08, 0.18, 0.08), color: hornColor)

        // Legs (4)
        let legSize = Float3(0.22, 0.7, 0.22)
        place(localCenter: Float3(-0.25, 0.35, -0.5), size: legSize, color: bodyColor)
        place(localCenter: Float3( 0.25, 0.35, -0.5), size: legSize, color: bodyColor)
        place(localCenter: Float3(-0.25, 0.35,  0.5), size: legSize, color: bodyColor)
        place(localCenter: Float3( 0.25, 0.35,  0.5), size: legSize, color: bodyColor)

        // Black spots — small flat-ish boxes on the body sides
        place(localCenter: Float3(0.36, 1.15,  0.3), size: Float3(0.05, 0.25, 0.30), color: spotColor)
        place(localCenter: Float3(-0.36, 1.05, -0.2), size: Float3(0.05, 0.20, 0.25), color: spotColor)
        place(localCenter: Float3(0.0, 1.45, 0.4),  size: Float3(0.40, 0.05, 0.25), color: spotColor)

        // Tail
        place(localCenter: Float3(0, 1.25, 0.85), size: Float3(0.10, 0.50, 0.10), color: bodyColor)
    }
}