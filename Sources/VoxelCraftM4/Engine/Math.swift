import simd
import Foundation

typealias Float3 = SIMD3<Float>
typealias Float4 = SIMD4<Float>
typealias Float4x4 = simd_float4x4

enum Math {
    static func perspective(fovyRadians: Float, aspect: Float, near: Float, far: Float) -> Float4x4 {
        let ys = 1 / tanf(fovyRadians * 0.5)
        let xs = ys / aspect
        let zs = far / (near - far)
        return Float4x4(columns: (
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1),
            SIMD4<Float>(0, 0, zs * near, 0)
        ))
    }

    static func translation(_ t: Float3) -> Float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
        return m
    }

    static func rotationX(_ a: Float) -> Float4x4 {
        let c = cosf(a), s = sinf(a)
        return Float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, c, s, 0),
            SIMD4<Float>(0, -s, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    static func rotationY(_ a: Float) -> Float4x4 {
        let c = cosf(a), s = sinf(a)
        return Float4x4(columns: (
            SIMD4<Float>(c, 0, -s, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(s, 0, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}

struct Uniforms {
    var viewProjection: Float4x4
    var model: Float4x4
    var cameraPos: Float3
    var _pad: Float = 0
    var lightDir: Float3
    var _pad2: Float = 0
}