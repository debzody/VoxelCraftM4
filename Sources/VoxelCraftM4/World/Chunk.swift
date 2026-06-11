import Foundation
import simd

struct Vertex {
    var position: Float3
    var normal: Float3
    var color: Float3
}

final class Chunk {
    static let sizeX = 16
    static let sizeY = 96
    static let sizeZ = 16
    static let seaLevel = 32
    static let snowLevel = 70

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

    // MARK: - Generation

    func generateTerrain(seed: UInt32) {
        let baseX = coord.x * Chunk.sizeX
        let baseZ = coord.y * Chunk.sizeZ

        // Heightmap with biome blending
        var heights = [[Int]](repeating: [Int](repeating: 0, count: Chunk.sizeZ), count: Chunk.sizeX)
        var biomes  = [[Biome]](repeating: [Biome](repeating: .plains, count: Chunk.sizeZ), count: Chunk.sizeX)

        for x in 0..<Chunk.sizeX {
            for z in 0..<Chunk.sizeZ {
                let wx = Float(baseX + x)
                let wz = Float(baseZ + z)
                let (h, b) = heightAndBiomeAt(wx, wz, seed: seed)
                let height = max(1, min(Chunk.sizeY - 2, Int(h)))
                heights[x][z] = height
                biomes[x][z] = b

                for y in 0..<Chunk.sizeY {
                    if y > height {
                        if y <= Chunk.seaLevel {
                            blocks[Chunk.index(x, y, z)] = .water
                        } else {
                            blocks[Chunk.index(x, y, z)] = .air
                        }
                    } else if y == height {
                        // Top block depends on biome and altitude
                        if height <= Chunk.seaLevel + 1 {
                            blocks[Chunk.index(x, y, z)] = .sand
                        } else if height >= Chunk.snowLevel {
                            blocks[Chunk.index(x, y, z)] = .snow
                        } else {
                            switch b {
                            case .desert: blocks[Chunk.index(x, y, z)] = .sand
                            case .mountains: blocks[Chunk.index(x, y, z)] = (height > Chunk.snowLevel - 6 ? .snow : .stone)
                            case .plains, .forest, .hills:
                                blocks[Chunk.index(x, y, z)] = .grass
                            }
                        }
                    } else if y > height - 4 {
                        // Subsurface
                        switch b {
                        case .desert: blocks[Chunk.index(x, y, z)] = .sand
                        case .mountains: blocks[Chunk.index(x, y, z)] = .stone
                        default: blocks[Chunk.index(x, y, z)] = .dirt
                        }
                    } else {
                        blocks[Chunk.index(x, y, z)] = .stone
                    }
                }
            }
        }

        // Trees in forest biome (and sometimes plains)
        for x in 2..<(Chunk.sizeX - 2) {
            for z in 2..<(Chunk.sizeZ - 2) {
                let h = heights[x][z]
                if h <= Chunk.seaLevel + 1 || h >= Chunk.snowLevel - 2 { continue }
                if blocks[Chunk.index(x, h, z)] != .grass { continue }

                let density: Float
                switch biomes[x][z] {
                case .forest:    density = 0.85
                case .plains:    density = 0.965
                case .hills:     density = 0.93
                case .mountains: density = 0.99
                case .desert:    density = 1.1   // never
                }
                let r = treeHash(baseX + x, baseZ + z, seed: seed)
                if r > density && h + 7 < Chunk.sizeY {
                    placeTree(x: x, y: h + 1, z: z)
                }
            }
        }

        meshDirty = true
    }

    private enum Biome {
        case plains, forest, hills, mountains, desert
    }

    /// Combined height + biome derivation.
    private func heightAndBiomeAt(_ x: Float, _ z: Float, seed: UInt32) -> (Float, Biome) {
        // Continent / large-scale relief
        let relief = Noise.value2D(x * 0.005, z * 0.005, seed: seed)        // -1..1
        // Mountain mask
        let mountainNoise = Noise.value2D(x * 0.012, z * 0.012, seed: seed &+ 7)
        // Mid-frequency hills
        let hills = Noise.value2D(x * 0.04, z * 0.04, seed: seed &+ 1)
        // Detail
        let detail = Noise.value2D(x * 0.12, z * 0.12, seed: seed &+ 2) * 0.4

        // Temperature/humidity for biomes
        let temp = Noise.value2D(x * 0.0035, z * 0.0035, seed: seed &+ 17)   // -1..1
        let humid = Noise.value2D(x * 0.004, z * 0.004, seed: seed &+ 31)

        // Determine biome
        let biome: Biome
        if mountainNoise > 0.45 {
            biome = .mountains
        } else if temp > 0.45 && humid < 0 {
            biome = .desert
        } else if humid > 0.2 {
            biome = .forest
        } else if hills > 0.3 {
            biome = .hills
        } else {
            biome = .plains
        }

        // Build height value depending on biome
        var h: Float
        switch biome {
        case .mountains:
            // Sharp mountains using ridged noise
            let ridged = 1 - abs(relief)
            h = 36 + ridged * 50 + hills * 14 + detail * 5
        case .hills:
            h = 30 + relief * 8 + hills * 14 + detail * 3
        case .forest:
            h = 30 + relief * 6 + hills * 8 + detail * 2
        case .plains:
            h = 28 + relief * 4 + hills * 4 + detail
        case .desert:
            h = 30 + relief * 4 + hills * 6 + detail
        }
        return (h, biome)
    }

    private func placeTree(x: Int, y: Int, z: Int) {
        let trunkH = Int.random(in: 4...6)
        for dy in 0..<trunkH {
            blocks[Chunk.index(x, y + dy, z)] = .wood
        }
        // Spherical canopy
        let topY = y + trunkH
        for dx in -2...2 {
            for dz in -2...2 {
                for dy in -1...2 {
                    let dist = abs(dx) + abs(dz) + abs(dy)
                    if dist > 4 { continue }
                    if dx == 0 && dz == 0 && dy < 0 { continue } // don't replace trunk
                    let nx = x + dx, ny = topY + dy, nz = z + dz
                    if nx < 0 || nx >= Chunk.sizeX { continue }
                    if nz < 0 || nz >= Chunk.sizeZ { continue }
                    if ny < 0 || ny >= Chunk.sizeY { continue }
                    if blocks[Chunk.index(nx, ny, nz)] == .air {
                        blocks[Chunk.index(nx, ny, nz)] = .leaves
                    }
                }
            }
        }
    }

    private func treeHash(_ x: Int, _ z: Int, seed: UInt32) -> Float {
        var h: UInt32 = seed &+ UInt32(bitPattern: Int32(x)) &* 73856093
                              &+ UInt32(bitPattern: Int32(z)) &* 19349663
        h = (h ^ (h &>> 13)) &* 1274126177
        h = h ^ (h &>> 16)
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    // MARK: - Mesh

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
