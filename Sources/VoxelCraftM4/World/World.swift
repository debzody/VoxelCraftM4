import Foundation
import simd

final class World {
    var chunks: [SIMD2<Int>: Chunk] = [:]
    let seed: UInt32 = 1337
    let viewRadius: Int = 8  // chunks each direction → ~17×17 = ~289 chunks

    func generate() {
        for cx in -viewRadius...viewRadius {
            for cz in -viewRadius...viewRadius {
                let coord = SIMD2<Int>(cx, cz)
                let chunk = Chunk(coord: coord)
                chunk.generateTerrain(seed: seed)
                chunks[coord] = chunk
            }
        }
        rebuildAllMeshes()
    }

    func rebuildAllMeshes() {
        for (_, chunk) in chunks {
            chunk.buildMesh(world: self)
        }
    }

    /// Returns block at world coords. Returns .air if outside loaded chunks.
    func blockAt(_ wx: Int, _ wy: Int, _ wz: Int) -> BlockType {
        if wy < 0 || wy >= Chunk.sizeY { return .air }
        let cx = Int(floor(Double(wx) / Double(Chunk.sizeX)))
        let cz = Int(floor(Double(wz) / Double(Chunk.sizeZ)))
        guard let chunk = chunks[SIMD2<Int>(cx, cz)] else { return .air }
        let lx = wx - cx * Chunk.sizeX
        let lz = wz - cz * Chunk.sizeZ
        return chunk.block(lx, wy, lz)
    }

    /// Returns whether block at world coords is opaque (used for face culling).
    func isOpaque(_ wx: Int, _ wy: Int, _ wz: Int) -> Bool {
        blockAt(wx, wy, wz).isOpaque
    }
}