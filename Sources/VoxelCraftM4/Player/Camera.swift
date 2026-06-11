import simd
import Foundation

final class Camera {
    var position: Float3 = Float3(8, 40, 30)
    var yaw: Float = 0       // radians, around Y
    var pitch: Float = -0.3  // radians, around X
    var fov: Float = 75 * .pi / 180
    var near: Float = 0.1
    var far: Float = 1000

    var forward: Float3 {
        Float3(
            cos(pitch) * sin(yaw),
            sin(pitch),
            -cos(pitch) * cos(yaw)
        )
    }

    var right: Float3 {
        normalize(cross(forward, Float3(0, 1, 0)))
    }

    var up: Float3 {
        normalize(cross(right, forward))
    }

    func viewMatrix() -> Float4x4 {
        let f = normalize(forward)
        let r = normalize(cross(f, Float3(0, 1, 0)))
        let u = cross(r, f)
        let t = Float3(-dot(r, position), -dot(u, position), dot(f, position))
        return Float4x4(columns: (
            SIMD4<Float>(r.x, u.x, -f.x, 0),
            SIMD4<Float>(r.y, u.y, -f.y, 0),
            SIMD4<Float>(r.z, u.z, -f.z, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)
        ))
    }

    func projectionMatrix(aspect: Float) -> Float4x4 {
        Math.perspective(fovyRadians: fov, aspect: aspect, near: near, far: far)
    }

    func viewProjection(aspect: Float) -> Float4x4 {
        projectionMatrix(aspect: aspect) * viewMatrix()
    }
}