import Foundation
import simd

/// Builds a Steve-like cuboid player body mesh based on Player position/yaw.
enum PlayerMesh {

    static func build(player: Player, into verts: inout [Vertex]) {
        guard !player.isDead else { return }   // hide body when dead (lying-down anim later)

        let cosY = cos(player.yaw)
        let sinY = sin(player.yaw)
        let basePos = player.position   // feet position

        // Local-Y stacking matches Minecraft Steve proportions (in blocks):
        //   legs: 0.6 tall → from y=0 to 0.6
        //   body: 0.6 tall → 0.6 to 1.2
        //   arms: 0.6 tall → 0.6 to 1.2 (alongside body)
        //   head: 0.6 cube → 1.2 to 1.8
        // Width: 0.5 across body, arms outside.

        func placeBox(localCenter: Float3, size: Float3, color: Float3) {
            // Rotate XZ around player yaw, translate
            let lx = localCenter.x, lz = localCenter.z
            let wx = basePos.x + (lx * cosY - lz * sinY)
            let wz = basePos.z + (lx * sinY + lz * cosY)
            let wy = basePos.y + localCenter.y

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
            quad(p100, p101, p111, p110, Float3( 1, 0, 0))
            quad(p001, p000, p010, p011, Float3(-1, 0, 0))
            quad(p010, p110, p111, p011, Float3( 0, 1, 0))
            quad(p000, p001, p101, p100, Float3( 0,-1, 0))
            quad(p101, p001, p011, p111, Float3( 0, 0, 1))
            quad(p000, p100, p110, p010, Float3( 0, 0,-1))
        }

        // Color palette (Steve)
        let skin   = Float3(0.95, 0.78, 0.62)
        let hair   = Float3(0.30, 0.18, 0.10)
        let shirt  = Float3(0.20, 0.70, 0.85)   // cyan
        let pants  = Float3(0.18, 0.18, 0.55)   // dark blue
        let shoes  = Float3(0.30, 0.20, 0.12)

        // ---- Legs (left & right) ----
        placeBox(localCenter: Float3(-0.13, 0.30,  0.0), size: Float3(0.25, 0.6, 0.25), color: pants)
        placeBox(localCenter: Float3( 0.13, 0.30,  0.0), size: Float3(0.25, 0.6, 0.25), color: pants)
        // Shoes (small overlay at the bottom)
        placeBox(localCenter: Float3(-0.13, 0.04,  0.0), size: Float3(0.27, 0.08, 0.27), color: shoes)
        placeBox(localCenter: Float3( 0.13, 0.04,  0.0), size: Float3(0.27, 0.08, 0.27), color: shoes)

        // ---- Body ----
        placeBox(localCenter: Float3(0.0, 0.90, 0.0), size: Float3(0.55, 0.6, 0.30), color: shirt)

        // ---- Arms (sleeves) ----
        placeBox(localCenter: Float3(-0.40, 0.90, 0.0), size: Float3(0.22, 0.6, 0.25), color: shirt)
        placeBox(localCenter: Float3( 0.40, 0.90, 0.0), size: Float3(0.22, 0.6, 0.25), color: shirt)
        // Hands (skin tip)
        placeBox(localCenter: Float3(-0.40, 0.62, 0.0), size: Float3(0.23, 0.10, 0.26), color: skin)
        placeBox(localCenter: Float3( 0.40, 0.62, 0.0), size: Float3(0.23, 0.10, 0.26), color: skin)

        // ---- Head ----
        placeBox(localCenter: Float3(0.0, 1.50, 0.0), size: Float3(0.55, 0.55, 0.55), color: skin)
        // Hair cap (top + back tinted darker)
        placeBox(localCenter: Float3(0.0, 1.70, 0.0), size: Float3(0.57, 0.18, 0.57), color: hair)
        // Tiny eyes — two black squares on the front face
        let eyeY: Float = 1.52
        placeBox(localCenter: Float3(-0.10, eyeY, -0.27), size: Float3(0.07, 0.07, 0.02), color: Float3(0.05,0.05,0.05))
        placeBox(localCenter: Float3( 0.10, eyeY, -0.27), size: Float3(0.07, 0.07, 0.02), color: Float3(0.05,0.05,0.05))
        // Mouth (small dark line)
        placeBox(localCenter: Float3(0.0, 1.40, -0.27), size: Float3(0.18, 0.03, 0.02), color: Float3(0.30,0.15,0.10))
    }
}