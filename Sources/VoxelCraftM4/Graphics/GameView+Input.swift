import Cocoa
import simd

extension GameView {

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)

        if event.keyCode == 53 { releaseMouse() }   // ESC
        // F (key 3) → toggle fly
        if event.keyCode == 3 {
            player.flying.toggle()
            if player.flying { player.velocity = Float3(0,0,0) }
        }
        // F5 (key 96) → cycle camera mode  (also map to V which is key 9)
        if event.keyCode == 96 || event.keyCode == 9 {
            switch player.cameraMode {
            case .first:      player.cameraMode = .thirdBack
            case .thirdBack:  player.cameraMode = .thirdFront
            case .thirdFront: player.cameraMode = .first
            }
        }
        // R (key 15) → respawn (also auto when dead long enough)
        if event.keyCode == 15 && player.isDead {
            player.respawn()
        }

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
        if player.isDead { return }
        if let hit = Raycast.cast(origin: player.eyePos, direction: player.forward,
                                  maxDistance: 6, world: world) {
            setBlock(at: (hit.blockX, hit.blockY, hit.blockZ), to: .air)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if !mouseCaptured { captureMouse(); return }
        if player.isDead { return }
        guard let hit = Raycast.cast(origin: player.eyePos, direction: player.forward,
                                     maxDistance: 6, world: world) else { return }
        let nx = hit.blockX + hit.normal.x
        let ny = hit.blockY + hit.normal.y
        let nz = hit.blockZ + hit.normal.z
        // Avoid placing into player body
        let pmin = Float3(player.position.x - Player.halfWidth, player.position.y, player.position.z - Player.halfWidth)
        let pmax = Float3(player.position.x + Player.halfWidth, player.position.y + Player.height, player.position.z + Player.halfWidth)
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

    override func mouseMoved(with event: NSEvent)        { handleMouseDelta(Float(event.deltaX), Float(event.deltaY)) }
    override func mouseDragged(with event: NSEvent)      { handleMouseDelta(Float(event.deltaX), Float(event.deltaY)) }
    override func rightMouseDragged(with event: NSEvent) { handleMouseDelta(Float(event.deltaX), Float(event.deltaY)) }

    private func handleMouseDelta(_ dx: Float, _ dy: Float) {
        guard mouseCaptured else { return }
        let s: Float = 0.0025
        player.yaw   += dx * s
        player.pitch -= dy * s
        let limit: Float = .pi / 2 - 0.01
        player.pitch = max(-limit, min(limit, player.pitch))
    }

    func captureMouse() {
        if !mouseCaptured { NSCursor.hide(); CGAssociateMouseAndMouseCursorPosition(0); mouseCaptured = true }
    }
    func releaseMouse() {
        if mouseCaptured { NSCursor.unhide(); CGAssociateMouseAndMouseCursorPosition(1); mouseCaptured = false }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.activeAlways, .mouseMoved, .inVisibleRect],
                                       owner: self, userInfo: nil))
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

    // MARK: - Player update (called every frame)

    func updatePlayer(dt: Float) {
        // Build a horizontal-plane wish direction from WASD relative to player yaw
        let fwdFlat = Float3(sin(player.yaw), 0, -cos(player.yaw))
        let rightFlat = Float3(cos(player.yaw), 0, sin(player.yaw))
        var wish = Float3(0, 0, 0)
        if keysDown.contains(13) { wish += fwdFlat }     // W
        if keysDown.contains(1)  { wish -= fwdFlat }     // S
        if keysDown.contains(2)  { wish += rightFlat }   // D
        if keysDown.contains(0)  { wish -= rightFlat }   // A

        // In flying mode, use full 3D wish (forward including pitch + WASD verticals)
        if player.flying {
            wish = Float3(0, 0, 0)
            if keysDown.contains(13) { wish += player.forward }
            if keysDown.contains(1)  { wish -= player.forward }
            if keysDown.contains(2)  { wish += player.right }
            if keysDown.contains(0)  { wish -= player.right }
            if keysDown.contains(49) { wish += Float3(0, 1, 0) }    // Space up
            if keysDown.contains(8)  { wish -= Float3(0, 1, 0) }    // C down
            if length(wish) > 0.0001 { wish = normalize(wish) }
        } else {
            if length(wish) > 0.0001 { wish = normalize(wish) }
        }

        let jump = keysDown.contains(49)               // Space
        let sprinting = keysDown.contains(56)          // Left Shift

        player.physicsStep(dt: dt, wishDir: wish, jump: jump, sprinting: sprinting, world: world)

        // Auto-respawn if dead for >2s and player presses anything (or just auto)
        if player.isDead && player.deathTimer > 3.0 {
            player.respawn()
        }
    }
}