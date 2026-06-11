import Cocoa
import simd

extension GameView {

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)
        if event.keyCode == 53 { releaseMouse() }   // ESC
        // Hotbar 1..7 (keys 18..24)
        let n = Int(event.keyCode) - 18
        if n >= 0 && n < hotbar.count { hotbarIndex = n; rebuildHUD() }
    }
    override func keyUp(with event: NSEvent) {
        keysDown.remove(event.keyCode)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if !mouseCaptured { captureMouse(); return }
        // Break block
        if let hit = Raycast.cast(origin: player.eyePos, direction: player.forward,
                                  maxDistance: 6, world: world) {
            setBlock(at: (hit.blockX, hit.blockY, hit.blockZ), to: .air)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if !mouseCaptured { captureMouse(); return }
        // Place block on hit face
        guard let hit = Raycast.cast(origin: player.eyePos, direction: player.forward,
                                     maxDistance: 6, world: world) else { return }
        let nx = hit.blockX + hit.normal.x
        let ny = hit.blockY + hit.normal.y
        let nz = hit.blockZ + hit.normal.z
        // Avoid placing into player's body
        let pmin = Float3(player.position.x - 0.3, player.position.y, player.position.z - 0.3)
        let pmax = Float3(player.position.x + 0.3, player.position.y + Player.height, player.position.z + 0.3)
        let bmin = Float3(Float(nx), Float(ny), Float(nz))
        let bmax = bmin + Float3(1, 1, 1)
        let overlap =
            pmin.x < bmax.x && pmax.x > bmin.x &&
            pmin.y < bmax.y && pmax.y > bmin.y &&
            pmin.z < bmax.z && pmax.z > bmin.z
        if !overlap {
            setBlock(at: (nx, ny, nz), to: hotbar[hotbarIndex])
        }
    }

    override func mouseMoved(with event: NSEvent) {
        handleMouseDelta(Float(event.deltaX), Float(event.deltaY))
    }
    override func mouseDragged(with event: NSEvent) {
        handleMouseDelta(Float(event.deltaX), Float(event.deltaY))
    }
    override func rightMouseDragged(with event: NSEvent) {
        handleMouseDelta(Float(event.deltaX), Float(event.deltaY))
    }

    private func handleMouseDelta(_ dx: Float, _ dy: Float) {
        guard mouseCaptured else { return }
        let s: Float = 0.0025
        player.yaw   += dx * s
        player.pitch -= dy * s
        let limit: Float = .pi / 2 - 0.01
        player.pitch = max(-limit, min(limit, player.pitch))
    }

    func captureMouse() {
        if !mouseCaptured {
            NSCursor.hide()
            CGAssociateMouseAndMouseCursorPosition(0)
            mouseCaptured = true
        }
    }

    func releaseMouse() {
        if mouseCaptured {
            NSCursor.unhide()
            CGAssociateMouseAndMouseCursorPosition(1)
            mouseCaptured = false
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    // MARK: - Block edit

    func setBlock(at p: (Int, Int, Int), to b: BlockType) {
        if p.1 < 0 || p.1 >= Chunk.sizeY { return }
        let cx = Int(floor(Double(p.0) / Double(Chunk.sizeX)))
        let cz = Int(floor(Double(p.2) / Double(Chunk.sizeZ)))
        guard let chunk = world.chunks[SIMD2<Int>(cx, cz)] else { return }
        let lx = p.0 - cx * Chunk.sizeX
        let lz = p.2 - cz * Chunk.sizeZ
        chunk.setBlock(lx, p.1, lz, b)
        rebuildOneChunk(SIMD2<Int>(cx, cz))
        if lx == 0                  { rebuildOneChunk(SIMD2<Int>(cx - 1, cz)) }
        if lx == Chunk.sizeX - 1    { rebuildOneChunk(SIMD2<Int>(cx + 1, cz)) }
        if lz == 0                  { rebuildOneChunk(SIMD2<Int>(cx, cz - 1)) }
        if lz == Chunk.sizeZ - 1    { rebuildOneChunk(SIMD2<Int>(cx, cz + 1)) }
    }

    // MARK: - Player movement update

    func updatePlayer(dt: Float) {
        var move = Float3(0, 0, 0)
        // W=13 S=1 A=0 D=2 Space=49 Shift=56 C=8 (FlyDown)
        if keysDown.contains(13) { move += player.forward }
        if keysDown.contains(1)  { move -= player.forward }
        if keysDown.contains(2)  { move += player.right }
        if keysDown.contains(0)  { move -= player.right }
        if keysDown.contains(49) { move += Float3(0, 1, 0) }
        if keysDown.contains(8)  { move -= Float3(0, 1, 0) }
        if length(move) > 0.0001 {
            move = normalize(move)
            let speed: Float = keysDown.contains(56) ? 30 : 12
            player.position += move * speed * dt
        }
    }
}