import Foundation

enum Noise {
    @inline(__always)
    private static func hashRand(_ x: Int32, _ y: Int32, _ seed: UInt32) -> Float {
        var h: UInt32 = seed &+ UInt32(bitPattern: x) &* 374761393 &+ UInt32(bitPattern: y) &* 668265263
        h = (h ^ (h &>> 13)) &* 1274126177
        h = h ^ (h &>> 16)
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF) * 2.0 - 1.0  // [-1, 1]
    }

    @inline(__always)
    private static func smooth(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    /// 2D value noise in [-1, 1]
    static func value2D(_ x: Float, _ y: Float, seed: UInt32) -> Float {
        let xi: Int32 = Int32(floorf(x))
        let yi: Int32 = Int32(floorf(y))
        let xf: Float = x - floorf(x)
        let yf: Float = y - floorf(y)

        let v00: Float = hashRand(xi,     yi,     seed)
        let v10: Float = hashRand(xi + 1, yi,     seed)
        let v01: Float = hashRand(xi,     yi + 1, seed)
        let v11: Float = hashRand(xi + 1, yi + 1, seed)

        let u: Float = smooth(xf)
        let v: Float = smooth(yf)

        let a: Float = v00 + (v10 - v00) * u
        let b: Float = v01 + (v11 - v01) * u
        return a + (b - a) * v
    }
}