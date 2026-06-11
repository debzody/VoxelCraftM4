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

                    let wlx = coord.x * Chunk.sizeX + x
                    let wlz = coord.y * Chunk.sizeZ + z
                    if !neighborOpaque(x + 1, y, z, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 0, color: b.color(face: 0),
                                  bx: wlx, by: y, bz: wlz, world: world)
                    }
                    if !neighborOpaque(x - 1, y, z, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 1, color: b.color(face: 1),
                                  bx: wlx, by: y, bz: wlz, world: world)
                    }
                    if !neighborOpaque(x, y + 1, z, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 2, color: b.color(face: 2),
                                  bx: wlx, by: y, bz: wlz, world: world)
                    }
                    if y > 0 && !neighborOpaque(x, y - 1, z, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 3, color: b.color(face: 3),
                                  bx: wlx, by: y, bz: wlz, world: world)
                    }
                    if !neighborOpaque(x, y, z + 1, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 4, color: b.color(face: 4),
                                  bx: wlx, by: y, bz: wlz, world: world)
                    }
                    if !neighborOpaque(x, y, z - 1, world: world) {
                        addFaceAO(&verts, wx: wx, wy: wy, wz: wz, face: 5, color: b.color(face: 5),
                                  bx: wlx, by: y, bz: wlz, world: world)
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

// MARK: - Ambient Occlusion mesh helpers

extension Chunk {
    /// Per-vertex AO: 0=no occlusion (full bright), 3=fully occluded (dark)
    /// Uses Minecraft-style 3-neighbor sample (side1, side2, corner).
    @inline(__always)
    static func aoFactor(side1: Bool, side2: Bool, corner: Bool) -> Int {
        if side1 && side2 { return 3 }   // both side neighbors solid → full dark
        return (side1 ? 1 : 0) + (side2 ? 1 : 0) + (corner ? 1 : 0)
    }

    @inline(__always)
    static func aoBrightness(_ ao: Int) -> Float {
        // 0..3 → brightness multiplier (1.0..0.55)
        switch ao {
        case 0: return 1.00
        case 1: return 0.85
        case 2: return 0.70
        default: return 0.55
        }
    }

    /// Build a face with per-vertex AO, then emit 6 triangle vertices using flipped diagonal
    /// when needed to avoid the AO "anisotropy" artifact.
    func addFaceAO(_ verts: inout [Vertex],
                   wx: Float, wy: Float, wz: Float, face: Int, color: Float3,
                   bx: Int, by: Int, bz: Int, world: World) {
        // Local helper to read solid neighbours in world coords
        @inline(__always) func s(_ x: Int, _ y: Int, _ z: Int) -> Bool { world.isOpaque(x, y, z) }

        // 4 corners of this face — each gets its own AO and position
        // Vertex order matches addFace's switch case
        var v: [(p: Float3, ao: Int)] = []

        switch face {
        case 0: // +X (east)
            // corners on the +X face plane (x = bx+1), going (y, z) from low/low to high/low → ...
            let corners: [(SIMD3<Int>, Float3)] = [
                (SIMD3<Int>(0, -1, -1), Float3(wx + 1, wy,     wz)),       // p100
                (SIMD3<Int>(0, -1,  1), Float3(wx + 1, wy,     wz + 1)),   // p101
                (SIMD3<Int>(0,  1,  1), Float3(wx + 1, wy + 1, wz + 1)),   // p111
                (SIMD3<Int>(0,  1, -1), Float3(wx + 1, wy + 1, wz))        // p110
            ]
            for c in corners {
                let side1 = s(bx + 1, by + c.0.y, bz)
                let side2 = s(bx + 1, by, bz + c.0.z)
                let corner = s(bx + 1, by + c.0.y, bz + c.0.z)
                let ao = Self.aoFactor(side1: side1, side2: side2, corner: corner)
                v.append((c.1, ao))
            }
            emitFace(&verts, v: v, normal: Float3(1, 0, 0), color: color)
        case 1: // -X (west)
            let corners: [(SIMD3<Int>, Float3)] = [
                (SIMD3<Int>(0, -1,  1), Float3(wx, wy,     wz + 1)),       // p001
                (SIMD3<Int>(0, -1, -1), Float3(wx, wy,     wz)),           // p000
                (SIMD3<Int>(0,  1, -1), Float3(wx, wy + 1, wz)),           // p010
                (SIMD3<Int>(0,  1,  1), Float3(wx, wy + 1, wz + 1))        // p011
            ]
            for c in corners {
                let side1 = s(bx - 1, by + c.0.y, bz)
                let side2 = s(bx - 1, by, bz + c.0.z)
                let corner = s(bx - 1, by + c.0.y, bz + c.0.z)
                let ao = Self.aoFactor(side1: side1, side2: side2, corner: corner)
                v.append((c.1, ao))
            }
            emitFace(&verts, v: v, normal: Float3(-1, 0, 0), color: color)
        case 2: // +Y (top)
            let corners: [(SIMD3<Int>, Float3)] = [
                (SIMD3<Int>(-1, 0, -1), Float3(wx,     wy + 1, wz)),       // p010
                (SIMD3<Int>( 1, 0, -1), Float3(wx + 1, wy + 1, wz)),       // p110
                (SIMD3<Int>( 1, 0,  1), Float3(wx + 1, wy + 1, wz + 1)),   // p111
                (SIMD3<Int>(-1, 0,  1), Float3(wx,     wy + 1, wz + 1))    // p011
            ]
            for c in corners {
                let side1 = s(bx + c.0.x, by + 1, bz)
                let side2 = s(bx, by + 1, bz + c.0.z)
                let corner = s(bx + c.0.x, by + 1, bz + c.0.z)
                let ao = Self.aoFactor(side1: side1, side2: side2, corner: corner)
                v.append((c.1, ao))
            }
            emitFace(&verts, v: v, normal: Float3(0, 1, 0), color: color)
        case 3: // -Y (bottom) — usually less visible, just give flat AO
            let corners: [Float3] = [
                Float3(wx,     wy, wz),     Float3(wx,     wy, wz + 1),
                Float3(wx + 1, wy, wz + 1), Float3(wx + 1, wy, wz)
            ]
            for c in corners { v.append((c, 1)) }
            emitFace(&verts, v: v, normal: Float3(0, -1, 0), color: color)
        case 4: // +Z (south)
            let corners: [(SIMD3<Int>, Float3)] = [
                (SIMD3<Int>( 1, -1, 0), Float3(wx + 1, wy,     wz + 1)),   // p101
                (SIMD3<Int>(-1, -1, 0), Float3(wx,     wy,     wz + 1)),   // p001
                (SIMD3<Int>(-1,  1, 0), Float3(wx,     wy + 1, wz + 1)),   // p011
                (SIMD3<Int>( 1,  1, 0), Float3(wx + 1, wy + 1, wz + 1))    // p111
            ]
            for c in corners {
                let side1 = s(bx + c.0.x, by, bz + 1)
                let side2 = s(bx, by + c.0.y, bz + 1)
                let corner = s(bx + c.0.x, by + c.0.y, bz + 1)
                let ao = Self.aoFactor(side1: side1, side2: side2, corner: corner)
                v.append((c.1, ao))
            }
            emitFace(&verts, v: v, normal: Float3(0, 0, 1), color: color)
        case 5: // -Z (north)
            let corners: [(SIMD3<Int>, Float3)] = [
                (SIMD3<Int>(-1, -1, 0), Float3(wx,     wy,     wz)),       // p000
                (SIMD3<Int>( 1, -1, 0), Float3(wx + 1, wy,     wz)),       // p100
                (SIMD3<Int>( 1,  1, 0), Float3(wx + 1, wy + 1, wz)),       // p110
                (SIMD3<Int>(-1,  1, 0), Float3(wx,     wy + 1, wz))        // p010
            ]
            for c in corners {
                let side1 = s(bx + c.0.x, by, bz - 1)
                let side2 = s(bx, by + c.0.y, bz - 1)
                let corner = s(bx + c.0.x, by + c.0.y, bz - 1)
                let ao = Self.aoFactor(side1: side1, side2: side2, corner: corner)
                v.append((c.1, ao))
            }
            emitFace(&verts, v: v, normal: Float3(0, 0, -1), color: color)
        default: break
        }
    }

    /// Emit 4-vertex face as 2 triangles, picking the diagonal that minimises AO interpolation artifact.
    private func emitFace(_ verts: inout [Vertex],
                          v: [(p: Float3, ao: Int)],
                          normal: Float3, color: Float3) {
        let v0 = v[0], v1 = v[1], v2 = v[2], v3 = v[3]
        let c0 = color * Self.aoBrightness(v0.ao)
        let c1 = color * Self.aoBrightness(v1.ao)
        let c2 = color * Self.aoBrightness(v2.ao)
        let c3 = color * Self.aoBrightness(v3.ao)

        // If diagonal v0-v2 has higher AO contrast, flip to v1-v3
        let flip = (v0.ao + v2.ao) > (v1.ao + v3.ao)

        if flip {
            // 0,1,3 + 1,2,3
            verts.append(Vertex(position: v0.p, normal: normal, color: c0))
            verts.append(Vertex(position: v1.p, normal: normal, color: c1))
            verts.append(Vertex(position: v3.p, normal: normal, color: c3))
            verts.append(Vertex(position: v1.p, normal: normal, color: c1))
            verts.append(Vertex(position: v2.p, normal: normal, color: c2))
            verts.append(Vertex(position: v3.p, normal: normal, color: c3))
        } else {
            // 0,1,2 + 0,2,3
            verts.append(Vertex(position: v0.p, normal: normal, color: c0))
            verts.append(Vertex(position: v1.p, normal: normal, color: c1))
            verts.append(Vertex(position: v2.p, normal: normal, color: c2))
            verts.append(Vertex(position: v0.p, normal: normal, color: c0))
            verts.append(Vertex(position: v2.p, normal: normal, color: c2))
            verts.append(Vertex(position: v3.p, normal: normal, color: c3))
        }
    }
}
