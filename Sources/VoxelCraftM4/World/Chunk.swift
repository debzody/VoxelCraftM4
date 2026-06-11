import Foundation
import simd

struct Vertex {
    var position: Float3
    var normal: Float3
    var color: Float3
}

final class Chunk {
    static let sizeX = 16
    static let sizeY = 64
    static let sizeZ = 16

    let coord: SIMD2<Int>     // chunk coords (x,z) in chunk space
    var blocks: [BlockType]   // flat array sizeX*sizeY*sizeZ
    var meshDirty: Bool = true
    var mesh: [Vertex] = []

    init(coord: SIMD2<Int>) {
        self.coord = coord
        self.blocks = Array(repeating: .air, count: Chunk.sizeX * Chunk.sizeY * Chunk.sizeZ)
    }

    @inline(__always)
    static func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        x + Chunk.sizeX * (z + Chunk.sizeZ * y)
    }

    func block(_ x: Int, _ y: Int, _ z: Int) -> BlockType {
        guard x >= 0, x < Chunk.sizeX, y >= 0, y < Chunk.sizeY, z >= 0, z < Chunk.sizeZ else {
            return .air
        }
        return blocks[Chunk.index(x, y, z)]
    }

    func setBlock(_ x: Int, _ y: Int, _ z: Int, _ b: BlockType) {
        blocks[Chunk.index(x, y, z)] = b
        meshDirty = true
    }

    /// Generate terrain using basic value noise + heightmap.
    func generateTerrain(seed: UInt32) {
        let baseX = coord.x * Chunk.sizeX
        let baseZ = coord.y * Chunk.sizeZ
        for x in 0..<Chunk.sizeX {
            for z in 0..<Chunk.sizeZ {
                let wx = Float(baseX + x)
                let wz = Float(baseZ + z)
                let h = heightAt(wx, wz, seed: seed)
                let height = max(1, min(Chunk.sizeY - 1, Int(h)))
                for y in 0..<Chunk.sizeY {
                    if y > height {
                        blocks[Chunk.index(x, y, z)] = .air
                    } else if y == height {
                        blocks[Chunk.index(x, y, z)] = (height < 18) ? .sand : .grass
                    } else if y > height - 4 {
                        blocks[Chunk.index(x, y, z)] = .dirt
                    } else {
                        blocks[Chunk.index(x, y, z)] = .stone
                    }
                }
            }
        }
        meshDirty = true
    }

    private func heightAt(_ x: Float, _ z: Float, seed: UInt32) -> Float {
        // Simple multi-octave value noise
        let n1 = Noise.value2D(x * 0.02, z * 0.02, seed: seed)
        let n2 = Noise.value2D(x * 0.05, z * 0.05, seed: seed &+ 1) * 0.5
        let n3 = Noise.value2D(x * 0.10, z * 0.10, seed: seed &+ 2) * 0.25
        let combined = (n1 + n2 + n3) / 1.75
        return 24 + combined * 18
    }

    /// Build mesh by iterating each block & emitting visible faces (no greedy meshing yet).
    func buildMesh(world: World) {
        var verts: [Vertex] = []
        verts.reserveCapacity(2048)

        let baseX = Float(coord.x * Chunk.sizeX)
        let baseZ = Float(coord.y * Chunk.sizeZ)

        for y in 0..<Chunk.sizeY {
            for z in 0..<Chunk.sizeZ {
                for x in 0..<Chunk.sizeX {
                    let b = blocks[Chunk.index(x, y, z)]
                    if b == .air { continue }

                    let wx = baseX + Float(x)
                    let wy = Float(y)
                    let wz = baseZ + Float(z)

                    // For each of 6 faces: check neighbor
                    // +X
                    if !world.isOpaque(coord.x * Chunk.sizeX + x + 1, y, coord.y * Chunk.sizeZ + z) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 0, color: b.color(face: 0))
                    }
                    // -X
                    if !world.isOpaque(coord.x * Chunk.sizeX + x - 1, y, coord.y * Chunk.sizeZ + z) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 1, color: b.color(face: 1))
                    }
                    // +Y (top)
                    if !world.isOpaque(coord.x * Chunk.sizeX + x, y + 1, coord.y * Chunk.sizeZ + z) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 2, color: b.color(face: 2))
                    }
                    // -Y (bottom)
                    if y > 0 && !world.isOpaque(coord.x * Chunk.sizeX + x, y - 1, coord.y * Chunk.sizeZ + z) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 3, color: b.color(face: 3))
                    }
                    // +Z
                    if !world.isOpaque(coord.x * Chunk.sizeX + x, y, coord.y * Chunk.sizeZ + z + 1) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 4, color: b.color(face: 4))
                    }
                    // -Z
                    if !world.isOpaque(coord.x * Chunk.sizeX + x, y, coord.y * Chunk.sizeZ + z - 1) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 5, color: b.color(face: 5))
                    }
                }
            }
        }

        self.mesh = verts
        self.meshDirty = false
    }

    private func addFace(_ verts: inout [Vertex], x: Float, y: Float, z: Float, face: Int, color: Float3) {
        // Cube corners
        let p000 = Float3(x,     y,     z)
        let p100 = Float3(x + 1, y,     z)
        let p010 = Float3(x,     y + 1, z)
        let p110 = Float3(x + 1, y + 1, z)
        let p001 = Float3(x,     y,     z + 1)
        let p101 = Float3(x + 1, y,     z + 1)
        let p011 = Float3(x,     y + 1, z + 1)
        let p111 = Float3(x + 1, y + 1, z + 1)

        switch face {
        case 0: // +X
            let n = Float3(1, 0, 0)
            quad(&verts, p100, p101, p111, p110, n, color)
        case 1: // -X
            let n = Float3(-1, 0, 0)
            quad(&verts, p001, p000, p010, p011, n, color)
        case 2: // +Y top
            let n = Float3(0, 1, 0)
            quad(&verts, p010, p110, p111, p011, n, color)
        case 3: // -Y bottom
            let n = Float3(0, -1, 0)
            quad(&verts, p000, p001, p101, p100, n, color)
        case 4: // +Z
            let n = Float3(0, 0, 1)
            quad(&verts, p101, p001, p011, p111, n, color)
        case 5: // -Z
            let n = Float3(0, 0, -1)
            quad(&verts, p000, p100, p110, p010, n, color)
        default: break
        }
    }

    private func quad(_ verts: inout [Vertex],
                      _ a: Float3, _ b: Float3, _ c: Float3, _ d: Float3,
                      _ n: Float3, _ color: Float3) {
        verts.append(Vertex(position: a, normal: n, color: color))
        verts.append(Vertex(position: b, normal: n, color: color))
        verts.append(Vertex(position: c, normal: n, color: color))
        verts.append(Vertex(position: a, normal: n, color: color))
        verts.append(Vertex(position: c, normal: n, color: color))
        verts.append(Vertex(position: d, normal: n, color: color))
    }
}