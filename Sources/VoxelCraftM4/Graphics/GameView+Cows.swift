import Foundation
import Metal
import simd

extension GameView {

    func spawnCows() {
        cows.removeAll()
        var attempts = 0
        while cows.count < 16 && attempts < 600 {
            attempts += 1
            let x = Int.random(in: -50...50)
            let z = Int.random(in: -50...50)
            var y = Chunk.sizeY - 1
            while y > 0 && world.blockAt(x, y, z) == .air { y -= 1 }
            if world.blockAt(x, y, z) == .grass {
                cows.append(Cow(position: Float3(Float(x) + 0.5, Float(y + 1), Float(z) + 0.5)))
            }
        }
        print("Spawned \(cows.count) cows.")
    }

    func updateCows(dt: Float) {
        for c in cows { c.update(dt: dt, world: world) }
        rebuildEntityMesh()
    }

    func rebuildEntityMesh() {
        guard let device = self.device else { return }
        var verts: [Vertex] = []
        verts.reserveCapacity(cows.count * 200)
        for c in cows { c.appendMesh(into: &verts) }
        entityVertexCount = verts.count
        if verts.isEmpty { entityBuffer = nil; return }
        let length = verts.count * MemoryLayout<Vertex>.stride
        entityBuffer = device.makeBuffer(bytes: verts, length: length, options: .storageModeShared)
    }

    func updateSelection() {
        guard let device = self.device else { return }
        let hit = Raycast.cast(origin: player.eyePos, direction: player.forward,
                               maxDistance: 6, world: world)
        guard let hit = hit else {
            selectionBuffer = nil; selectionVertexCount = 0; return
        }
        var verts: [Vertex] = []
        let bx = Float(hit.blockX), by = Float(hit.blockY), bz = Float(hit.blockZ)
        let pad: Float = 0.005
        let t: Float = 0.04
        let edgeColor = Float3(0.05, 0.05, 0.05)

        // 12 edges, each a thin axis-aligned box
        // X-edges
        for (yo, zo) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
            appendSelBox(&verts,
                         min: Float3(bx - pad,    by + Float(yo) - t/2, bz + Float(zo) - t/2),
                         max: Float3(bx + 1 + pad, by + Float(yo) + t/2, bz + Float(zo) + t/2),
                         color: edgeColor)
        }
        // Y-edges
        for (xo, zo) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
            appendSelBox(&verts,
                         min: Float3(bx + Float(xo) - t/2, by - pad,     bz + Float(zo) - t/2),
                         max: Float3(bx + Float(xo) + t/2, by + 1 + pad, bz + Float(zo) + t/2),
                         color: edgeColor)
        }
        // Z-edges
        for (xo, yo) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
            appendSelBox(&verts,
                         min: Float3(bx + Float(xo) - t/2, by + Float(yo) - t/2, bz - pad),
                         max: Float3(bx + Float(xo) + t/2, by + Float(yo) + t/2, bz + 1 + pad),
                         color: edgeColor)
        }

        selectionVertexCount = verts.count
        let length = verts.count * MemoryLayout<Vertex>.stride
        selectionBuffer = device.makeBuffer(bytes: verts, length: length, options: .storageModeShared)
    }

    private func appendSelBox(_ verts: inout [Vertex], min mn: Float3, max mx: Float3, color: Float3) {
        let p000 = Float3(mn.x, mn.y, mn.z)
        let p100 = Float3(mx.x, mn.y, mn.z)
        let p010 = Float3(mn.x, mx.y, mn.z)
        let p110 = Float3(mx.x, mx.y, mn.z)
        let p001 = Float3(mn.x, mn.y, mx.z)
        let p101 = Float3(mx.x, mn.y, mx.z)
        let p011 = Float3(mn.x, mx.y, mx.z)
        let p111 = Float3(mx.x, mx.y, mx.z)

        func quad(_ a: Float3, _ b: Float3, _ c: Float3, _ d: Float3, _ n: Float3) {
            verts.append(Vertex(position: a, normal: n, color: color))
            verts.append(Vertex(position: b, normal: n, color: color))
            verts.append(Vertex(position: c, normal: n, color: color))
            verts.append(Vertex(position: a, normal: n, color: color))
            verts.append(Vertex(position: c, normal: n, color: color))
            verts.append(Vertex(position: d, normal: n, color: color))
        }
        quad(p100, p101, p111, p110, Float3( 1, 0, 0))
        quad(p001, p000, p010, p011, Float3(-1, 0, 0))
        quad(p010, p110, p111, p011, Float3( 0, 1, 0))
        quad(p000, p001, p101, p100, Float3( 0,-1, 0))
        quad(p101, p001, p011, p111, Float3( 0, 0, 1))
        quad(p000, p100, p110, p010, Float3( 0, 0,-1))
    }
}