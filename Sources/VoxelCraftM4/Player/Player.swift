import Foundation
import simd

final class Player {
    var position: Float3 = Float3(8, 60, 30)
    var velocity: Float3 = Float3(0, 0, 0)
    var yaw: Float = 0
    var pitch: Float = -0.4

    // Body dimensions (in blocks)
    static let halfWidth: Float = 0.3
    static let height: Float = 1.8
    static let eyeHeight: Float = 1.65

    var onGround: Bool = false
    var flying: Bool = true   // start in fly mode for easy exploration

    var forward: Float3 {
        Float3(cos(pitch) * sin(yaw), sin(pitch), -cos(pitch) * cos(yaw))
    }
    var forwardFlat: Float3 {
        let f = Float3(sin(yaw), 0, -cos(yaw))
        return normalize(f)
    }
    var right: Float3 {
        normalize(cross(forward, Float3(0, 1, 0)))
    }
    var eyePos: Float3 {
        Float3(position.x, position.y + Player.eyeHeight, position.z)
    }

    func viewMatrix() -> Float4x4 {
        let f = normalize(forward)
        let r = normalize(cross(f, Float3(0, 1, 0)))
        let u = cross(r, f)
        let p = eyePos
        let t = Float3(-dot(r, p), -dot(u, p), dot(f, p))
        return Float4x4(columns: (
            SIMD4<Float>(r.x, u.x, -f.x, 0),
            SIMD4<Float>(r.y, u.y, -f.y, 0),
            SIMD4<Float>(r.z, u.z, -f.z, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)
        ))
    }

    func projectionMatrix(aspect: Float) -> Float4x4 {
        Math.perspective(fovyRadians: 75 * .pi / 180, aspect: aspect, near: 0.1, far: 1000)
    }

    func viewProjection(aspect: Float) -> Float4x4 {
        projectionMatrix(aspect: aspect) * viewMatrix()
    }
}