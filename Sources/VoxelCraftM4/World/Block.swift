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

    var isSolid: Bool { self != .air && self != .water }
    var isOpaque: Bool { self != .air && self != .water && self != .leaves }

    /// Returns RGB color per face. Index: 0+X, 1-X, 2+Y(top), 3-Y(bot), 4+Z, 5-Z
    func color(face: Int) -> Float3 {
        switch self {
        case .air:    return Float3(0, 0, 0)
        case .grass:
            if face == 2 { return Float3(0.30, 0.75, 0.25) } // top - green
            if face == 3 { return Float3(0.45, 0.30, 0.18) } // bottom - dirt
            return Float3(0.40, 0.55, 0.22) // side - mixed
        case .dirt:   return Float3(0.45, 0.30, 0.18)
        case .stone:  return Float3(0.55, 0.55, 0.58)
        case .sand:   return Float3(0.92, 0.86, 0.62)
        case .wood:   return Float3(0.45, 0.30, 0.15)
        case .leaves: return Float3(0.20, 0.55, 0.20)
        case .water:  return Float3(0.15, 0.40, 0.85)
        }
    }
}