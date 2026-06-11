import Foundation
import simd

/// Builds a Steve-like cuboid player body mesh based on Player position/yaw.
/// Now with walk animation: legs and arms swing when player is moving.
enum PlayerMesh {

    static func build(player: Player, into verts: inout [Vertex]) {
        guard !player.isDead else { return }

        let cosY = cos(player.yaw)
        let sinY = sin(player.yaw)
        let basePos = player.position

        // ----- Compute limb swing angles -----
        // sin(animPhase) for legs, -sin(animPhase) for arms (opposite sides)
        // Amplitude scales with speed (0 when idle, ~30 deg when sprinting)
        let speedXZ = sqrt(player.velocity.x * player.velocity.x + player.velocity.z * player.velocity.z)
        let isWalking = speedXZ > 0.5 || player.flying == false  // Always show animation if not flying — we'll detect via a movement timer in Player
        // Use the Player.walkPhase which we'll add (driven by physicsStep)
        let phase = player.walkPhase
        let swingAmplitude: Float = isWalking ? min(0.55, speedXZ * 0.08) : 0
        let legAngle = sin(phase) * swingAmplitude
        let armAngle = -sin(phase) * swingAmplitude

        // Helper: rotate a local-Z offset by an X-axis pivot rotation, then apply yaw + translate.
        // For a hinge rotating around X (so the limb swings forward/back along Z),
        // a point (lx, ly, lz) above pivot at (px, py, pz) becomes:
        //   ly' = (ly - py) * cos(angle) - (lz - pz) * sin(angle) + py
        //   lz' = (ly - py) * sin(angle) + (lz - pz) * cos(angle) + pz
        func rotX(_ point: Float3, pivot: Float3, angle: Float) -> Float3 {
            let py = point.y - pivot.y
            let pz = point.z - pivot.z
            let c = cos(angle), s = sin(angle)
            return Float3(
                point.x,
                py * c - pz * s + pivot.y,
                py * s + pz * c + pivot.z
            )
        }

        // Place a cube. localCenter is in player-local space (un-rotated).
        // If `swingAngle` and `pivotLocal` are given, rotate the box around X axis at pivotLocal first.
        func placeBox(localCenter: Float3, size: Float3, color: Float3,
                      swingAngle: Float = 0, pivotLocal: Float3 = .zero) {
            // 8 corners in player-local space, before yaw
            let h = size * 0.5
            var corners: [Float3] = [
                Float3(localCenter.x - h.x, localCenter.y - h.y, localCenter.z - h.z),
                Float3(localCenter.x + h.x, localCenter.y - h.y, localCenter.z - h.z),
                Float3(localCenter.x - h.x, localCenter.y + h.y, localCenter.z - h.z),
                Float3(localCenter.x + h.x, localCenter.y + h.y, localCenter.z - h.z),
                Float3(localCenter.x - h.x, localCenter.y - h.y, localCenter.z + h.z),
                Float3(localCenter.x + h.x, localCenter.y - h.y, localCenter.z + h.z),
                Float3(localCenter.x - h.x, localCenter.y + h.y, localCenter.z + h.z),
                Float3(localCenter.x + h.x, localCenter.y + h.y, localCenter.z + h.z),
            ]
            if abs(swingAngle) > 0.001 {
                for i in 0..<8 {
                    corners[i] = rotX(corners[i], pivot: pivotLocal, angle: swingAngle)
                }
            }
            // Apply yaw + translate
            for i in 0..<8 {
                let lx = corners[i].x, lz = corners[i].z
                corners[i] = Float3(
                    basePos.x + (lx * cosY - lz * sinY),
                    basePos.y + corners[i].y,
                    basePos.z + (lx * sinY + lz * cosY)
                )
            }

            let p000 = corners[0], p100 = corners[1]
            let p010 = corners[2], p110 = corners[3]
            let p001 = corners[4], p101 = corners[5]
            let p011 = corners[6], p111 = corners[7]

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

        // Color palette
        let skin   = Float3(0.95, 0.78, 0.62)
        let hair   = Float3(0.30, 0.18, 0.10)
        let shirt  = Float3(0.20, 0.70, 0.85)
        let pants  = Float3(0.18, 0.18, 0.55)
        let shoes  = Float3(0.30, 0.20, 0.12)

        // ---- Legs (animated swing around hip Y=0.6) ----
        let legPivotY: Float = 0.6
        // Right leg swings forward (positive), left leg backward (negative)
        placeBox(localCenter: Float3(-0.13, 0.30,  0.0), size: Float3(0.25, 0.6, 0.25), color: pants,
                 swingAngle: -legAngle, pivotLocal: Float3(-0.13, legPivotY, 0))
        placeBox(localCenter: Float3( 0.13, 0.30,  0.0), size: Float3(0.25, 0.6, 0.25), color: pants,
                 swingAngle:  legAngle, pivotLocal: Float3( 0.13, legPivotY, 0))
        // Shoes follow legs
        placeBox(localCenter: Float3(-0.13, 0.04,  0.0), size: Float3(0.27, 0.08, 0.27), color: shoes,
                 swingAngle: -legAngle, pivotLocal: Float3(-0.13, legPivotY, 0))
        placeBox(localCenter: Float3( 0.13, 0.04,  0.0), size: Float3(0.27, 0.08, 0.27), color: shoes,
                 swingAngle:  legAngle, pivotLocal: Float3( 0.13, legPivotY, 0))

        // ---- Body (still) ----
        placeBox(localCenter: Float3(0.0, 0.90, 0.0), size: Float3(0.55, 0.6, 0.30), color: shirt)

        // ---- Arms (animated, swing opposite to legs around shoulder Y=1.2) ----
        let shoulderY: Float = 1.20
        placeBox(localCenter: Float3(-0.40, 0.90, 0.0), size: Float3(0.22, 0.6, 0.25), color: shirt,
                 swingAngle:  armAngle, pivotLocal: Float3(-0.40, shoulderY, 0))
        placeBox(localCenter: Float3( 0.40, 0.90, 0.0), size: Float3(0.22, 0.6, 0.25), color: shirt,
                 swingAngle: -armAngle, pivotLocal: Float3( 0.40, shoulderY, 0))
        // Hands
        placeBox(localCenter: Float3(-0.40, 0.62, 0.0), size: Float3(0.23, 0.10, 0.26), color: skin,
                 swingAngle:  armAngle, pivotLocal: Float3(-0.40, shoulderY, 0))
        placeBox(localCenter: Float3( 0.40, 0.62, 0.0), size: Float3(0.23, 0.10, 0.26), color: skin,
                 swingAngle: -armAngle, pivotLocal: Float3( 0.40, shoulderY, 0))

        // ---- Head (still, but bobs slightly with phase) ----
        let headBob: Float = sin(phase * 2) * 0.02 * (isWalking ? 1 : 0)
        placeBox(localCenter: Float3(0.0, 1.50 + headBob, 0.0), size: Float3(0.55, 0.55, 0.55), color: skin)
        placeBox(localCenter: Float3(0.0, 1.70 + headBob, 0.0), size: Float3(0.57, 0.18, 0.57), color: hair)
        let eyeY: Float = 1.52 + headBob
        placeBox(localCenter: Float3(-0.10, eyeY, -0.27), size: Float3(0.07, 0.07, 0.02), color: Float3(0.05,0.05,0.05))
        placeBox(localCenter: Float3( 0.10, eyeY, -0.27), size: Float3(0.07, 0.07, 0.02), color: Float3(0.05,0.05,0.05))
        placeBox(localCenter: Float3(0.0, 1.40 + headBob, -0.27), size: Float3(0.18, 0.03, 0.02), color: Float3(0.30,0.15,0.10))
    }
}