import Foundation
import simd

struct Vertex {
    var position: Float3
    var normal: Float3
    var color: Float3
}

final class Chunk {
    static let sizeX = 16
    static let sizeY = 80
    static let sizeZ = 16
    static let seaLevel = 22
    static let snowLevel = 46

    let coord: SIMD2<Int>
    var blocks: [BlockType]
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

    func generateTerrain(seed: UInt32) {
        let baseX = coord.x * Chunk.sizeX
        let baseZ = coord.y * Chunk.sizeZ

        // 1) Heightmap + base layers
        var heights = [[Int]](repeating: [Int](repeating: 0, count: Chunk.sizeZ), count: Chunk.sizeX)
        for x in 0..<Chunk.sizeX {
            for z in 0..<Chunk.sizeZ {
                let wx = Float(baseX + x)
                let wz = Float(baseZ + z)
                let h = heightAt(wx, wz, seed: seed)
                let height = max(1, min(Chunk.sizeY - 2, Int(h)))
                heights[x][z] = height

                for y in 0..<Chunk.sizeY {
                    if y > height {
                        if y <= Chunk.seaLevel {
                            blocks[Chunk.index(x, y, z)] = .water
                        } else {
                            blocks[Chunk.index(x, y, z)] = .air
                        }
                    } else if y == height {
                        if height <= Chunk.seaLevel + 1 {
                            blocks[Chunk.index(x, y, z)] = .sand
                        } else if height >= Chunk.snowLevel {
                            blocks[Chunk.index(x, y, z)] = .snow
                        } else {
                            blocks[Chunk.index(x, y, z)] = .grass
                        }
                    } else if y > height - 4 {
                        blocks[Chunk.index(x, y, z)] = (height >= Chunk.snowLevel - 2) ? .stone : .dirt
                    } else {
                        blocks[Chunk.index(x, y, z)] = .stone
                    }
                }
            }
        }

        // 2) Trees: random placement on grass tops
        for x in 2..<(Chunk.sizeX - 2) {
            for z in 2..<(Chunk.sizeZ - 2) {
                let h = heights[x][z]
                if h <= Chunk.seaLevel + 1 || h >= Chunk.snowLevel - 2 { continue }
                if blocks[Chunk.index(x, h, z)] != .grass { continue }

                // Hash to decide if a tree spawns here
                let hash = treeHash(baseX + x, baseZ + z, seed: seed)
                if hash > 0.93 && h + 6 < Chunk.sizeY {
                    placeTree(x: x, y: h + 1, z: z)
                }
            }
        }

        meshDirty = true
    }

    private func placeTree(x: Int, y: Int, z: Int) {
        // 4-block trunk
        for dy in 0..<4 {
            blocks[Chunk.index(x, y + dy, z)] = .wood
        }
        // 3x3x2 leaf canopy
        for dx in -2...2 {
            for dz in -2...2 {
                for dy in 3...5 {
                    let dist = abs(dx) + abs(dz) + (dy - 4) * 2
                    if dist > 4 { continue }
                    let nx = x + dx, ny = y + dy, nz = z + dz
                    if nx < 0 || nx >= Chunk.sizeX { continue }
                    if nz < 0 || nz >= Chunk.sizeZ { continue }
                    if ny < 0 || ny >= Chunk.sizeY { continue }
                    if blocks[Chunk.index(nx, ny, nz)] == .air {
                        blocks[Chunk.index(nx, ny, nz)] = .leaves
                    }
                }
            }
        }
        // Top leaf
        if y + 6 < Chunk.sizeY {
            blocks[Chunk.index(x, y + 5, z)] = .leaves
        }
    }

    private func treeHash(_ x: Int, _ z: Int, seed: UInt32) -> Float {
        var h: UInt32 = seed &+ UInt32(bitPattern: Int32(x)) &* 73856093
                              &+ UInt32(bitPattern: Int32(z)) &* 19349663
        h = (h ^ (h &>> 13)) &* 1274126177
        h = h ^ (h &>> 16)
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    private func heightAt(_ x: Float, _ z: Float, seed: UInt32) -> Float {
        let n1 = Noise.value2D(x * 0.015, z * 0.015, seed: seed)
        let n2 = Noise.value2D(x * 0.04,  z * 0.04,  seed: seed &+ 1) * 0.5
        let n3 = Noise.value2D(x * 0.10,  z * 0.10,  seed: seed &+ 2) * 0.25
        let combined: Float = (n1 + n2 + n3) / 1.75
        // ridged-ish to make hills more distinct
        let amplified: Float = combined * combined * (combined > 0 ? 1.0 : -1.0)
        return 26.0 + amplified * 28.0
    }

    func buildMesh(world: World) {
        var verts: [Vertex] = []
        verts.reserveCapacity(4096)

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

                    // For water, only emit the top face (and only if no water above)
                    if b == .water {
                        let above = world.blockAt(coord.x * Chunk.sizeX + x, y + 1, coord.y * Chunk.sizeZ + z)
                        if above == .air {
                            addFace(&verts, x: wx, y: wy - 0.15, z: wz, face: 2, color: b.color(face: 2))
                        }
                        continue
                    }

                    if !neighborOpaque(x + 1, y, z, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 0, color: b.color(face: 0))
                    }
                    if !neighborOpaque(x - 1, y, z, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 1, color: b.color(face: 1))
                    }
                    if !neighborOpaque(x, y + 1, z, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 2, color: b.color(face: 2))
                    }
                    if y > 0 && !neighborOpaque(x, y - 1, z, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 3, color: b.color(face: 3))
                    }
                    if !neighborOpaque(x, y, z + 1, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 4, color: b.color(face: 4))
                    }
                    if !neighborOpaque(x, y, z - 1, world: world) {
                        addFace(&verts, x: wx, y: wy, z: wz, face: 5, color: b.color(face: 5))
                    }
                }
            }
        }

        self.mesh = verts
        self.meshDirty = false
    }

    @inline(__always)
    private func neighborOpaque(_ lx: Int, _ ly: Int, _ lz: Int, world: World) -> Bool {
        let wx = coord.x * Chunk.sizeX + lx
        let wz = coord.y * Chunk.sizeZ + lz
        return world.isOpaque(wx, ly, wz)
    }

    private func addFace(_ verts: inout [Vertex], x: Float, y: Float, z: Float, face: Int, color: Float3) {
        let p000 = Float3(x,     y,     z)
        let p100 = Float3(x + 1, y,     z)
        let p010 = Float3(x,     y + 1, z)
        let p110 = Float3(x + 1, y + 1, z)
        let p001 = Float3(x,     y,     z + 1)
        let p101 = Float3(x + 1, y,     z + 1)
        let p011 = Float3(x,     y + 1, z + 1)
        let p111 = Float3(x + 1, y + 1, z + 1)

        switch face {
        case 0: quad(&verts, p100, p101, p111, p110, Float3(1, 0, 0), color)
        case 1: quad(&verts, p001, p000, p010, p011, Float3(-1, 0, 0), color)
        case 2: quad(&verts, p010, p110, p111, p011, Float3(0, 1, 0), color)
        case 3: quad(&verts, p000, p001, p101, p100, Float3(0, -1, 0), color)
        case 4: quad(&verts, p101, p001, p011, p111, Float3(0, 0, 1), color)
        case 5: quad(&verts, p000, p100, p110, p010, Float3(0, 0, -1), color)
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