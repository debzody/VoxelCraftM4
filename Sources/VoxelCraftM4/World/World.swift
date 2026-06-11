import Foundation
import simd

final class World {
    var chunks: [SIMD2<Int>: Chunk] = [:]
    let seed: UInt32 = 1337

    /// Render distance in chunks (each direction). 12 = ~25×25 chunks loaded.
    var viewRadius: Int = 12

    /// Initial generation around the origin.
    func generateInitial(around: SIMD2<Int> = .zero) {
        let r = min(viewRadius, 8)  // start smaller so first launch is fast
        for cx in (around.x - r)...(around.x + r) {
            for cz in (around.y - r)...(around.y + r) {
                ensureChunk(at: SIMD2<Int>(cx, cz))
            }
        }
        rebuildAllMeshes()
    }

    /// Returns true if a chunk was newly created.
    @discardableResult
    func ensureChunk(at coord: SIMD2<Int>) -> Bool {
        if chunks[coord] != nil { return false }
        let chunk = Chunk(coord: coord)
        chunk.generateTerrain(seed: seed)
        chunks[coord] = chunk
        return true
    }

    /// Stream chunks around the player. Returns:
    ///  - newlyAdded: chunks that were just generated (need first mesh build)
    ///  - removed:    chunks that were unloaded (need their GPU buffers cleared)
    /// Caller is expected to (re)build meshes for new chunks AND for the
    /// neighbours of any removed chunks (so faces appear correctly).
    func streamChunks(around playerChunk: SIMD2<Int>) -> (newlyAdded: [SIMD2<Int>], removed: [SIMD2<Int>]) {
        var newlyAdded: [SIMD2<Int>] = []
        var removed: [SIMD2<Int>] = []

        let r = viewRadius
        // Add new chunks near player
        for cx in (playerChunk.x - r)...(playerChunk.x + r) {
            for cz in (playerChunk.y - r)...(playerChunk.y + r) {
                let dx = cx - playerChunk.x
                let dz = cz - playerChunk.y
                if dx * dx + dz * dz > r * r { continue }   // circular radius
                let coord = SIMD2<Int>(cx, cz)
                if ensureChunk(at: coord) {
                    newlyAdded.append(coord)
                }
            }
        }

        // Remove chunks beyond unload radius
        let unloadR = r + 2
        for (coord, _) in chunks {
            let dx = coord.x - playerChunk.x
            let dz = coord.y - playerChunk.y
            if dx * dx + dz * dz > unloadR * unloadR {
                chunks.removeValue(forKey: coord)
                removed.append(coord)
            }
        }

        return (newlyAdded, removed)
    }

    func rebuildAllMeshes() {
        for (_, chunk) in chunks {
            chunk.buildMesh(world: self)
        }
    }

    /// Block at world coords. Returns .air if outside loaded chunks (so we don't render unnecessary faces).
    func blockAt(_ wx: Int, _ wy: Int, _ wz: Int) -> BlockType {
        if wy < 0 || wy >= Chunk.sizeY { return .air }
        let cx = Int(floor(Double(wx) / Double(Chunk.sizeX)))
        let cz = Int(floor(Double(wz) / Double(Chunk.sizeZ)))
        guard let chunk = chunks[SIMD2<Int>(cx, cz)] else { return .air }
        let lx = wx - cx * Chunk.sizeX
        let lz = wz - cz * Chunk.sizeZ
        return chunk.block(lx, wy, lz)
    }

    /// Whether a block is opaque (used for face culling).
    func isOpaque(_ wx: Int, _ wy: Int, _ wz: Int) -> Bool {
        blockAt(wx, wy, wz).isOpaque
    }

    /// Convert a world position to chunk coord.
    static func chunkOf(worldPos: Float3) -> SIMD2<Int> {
        SIMD2<Int>(
            Int(floor(worldPos.x / Float(Chunk.sizeX))),
            Int(floor(worldPos.z / Float(Chunk.sizeZ)))
        )
    }
}