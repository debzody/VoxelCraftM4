import Cocoa
import Metal
import MetalKit
import simd

extension GameView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        let dt = Float(min(now - lastFrameTime, 0.1))
        lastFrameTime = now

        // FPS counter
        fpsAccumTime += Double(dt)
        frameCount += 1
        if fpsAccumTime >= 1.0 {
            let fps = Double(frameCount) / fpsAccumTime
            let modeStr: String = {
                switch player.cameraMode {
                case .first: return "1st"
                case .thirdBack: return "3rd-back"
                case .thirdFront: return "3rd-front"
                }
            }()
            let stateStr = player.isDead ? "💀 DEAD (R/auto-respawn)"
                          : player.flying ? "✈ FLY"
                          : (player.onGround ? "🚶 GROUND" : "🪂 AIR")
            window?.title = String(format:
                "VoxelCraft M4 — %.0f FPS — HP %d/%d — %@ — view: %@ — block: %@",
                fps, player.health, player.maxHealth,
                stateStr, modeStr, "\(hotbar[hotbarIndex])")
            fpsAccumTime = 0
            frameCount = 0
        }

        updatePlayer(dt: dt)
        updateCows(dt: dt)
        updateSelection()
        rebuildHUD()

        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
        var uniforms = Uniforms(
            viewProjection: player.viewProjection(aspect: aspect),
            model: matrix_identity_float4x4,
            cameraPos: player.eyePos,
            lightDir: normalize(Float3(-0.4, -1.0, -0.3))
        )

        // === 3D pass ===
        enc.setRenderPipelineState(pipelineState)
        enc.setDepthStencilState(depthState)
        enc.setCullMode(.none)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        // Chunks
        for (_, entry) in chunkBuffers {
            enc.setVertexBuffer(entry.buffer, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: entry.vertexCount)
        }

        // Cows
        if let buf = entityBuffer, entityVertexCount > 0 {
            enc.setVertexBuffer(buf, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: entityVertexCount)
        }

        // Selection wireframe
        if let buf = selectionBuffer, selectionVertexCount > 0 {
            enc.setVertexBuffer(buf, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: selectionVertexCount)
        }

        // === 2D HUD pass ===
        if let hud = hudBuffer, hudVertexCount > 0 {
            enc.setRenderPipelineState(pipelineState2D)
            enc.setVertexBuffer(hud, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: hudVertexCount)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
}