import Foundation
import simd

enum BlockType: UInt8 {
    case air = 0
    case grass = 1
    case dirt = 2
    case stone = 3
    case sand = 4
    case wood = 5
    case leaves = 6
    case water = 7
    case snow = 8

    var isSolid: Bool { self != .air && self != .water }
    var isOpaque: Bool { self != .air && self != .water && self != .leaves }

    /// Returns RGB color per face. Index: 0+X, 1-X, 2+Y(top), 3-Y(bot), 4+Z, 5-Z
    func color(face: Int) -> Float3 {
        switch self {
        case .air:    return Float3(0, 0, 0)
        case .grass:
            if face == 2 { return Float3(0.36, 0.82, 0.32) }   // top: vivid green
            if face == 3 { return Float3(0.55, 0.38, 0.22) }   // bottom: dirt
            // Side: dirt with green strip on top — emulate by mixing
            return Float3(0.45, 0.62, 0.28)
        case .dirt:   return Float3(0.55, 0.38, 0.22)
        case .stone:  return Float3(0.62, 0.62, 0.66)
        case .sand:   return Float3(0.96, 0.90, 0.66)
        case .wood:
            if face == 2 || face == 3 { return Float3(0.62, 0.45, 0.25) } // rings on top/bottom
            return Float3(0.50, 0.34, 0.18)
        case .leaves: return Float3(0.28, 0.62, 0.24)
        case .water:  return Float3(0.18, 0.45, 0.85)
        case .snow:   return Float3(0.96, 0.97, 1.00)
        }
    }
}