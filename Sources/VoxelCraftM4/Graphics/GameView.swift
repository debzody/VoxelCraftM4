import Cocoa
import Metal
import MetalKit
import simd

final class GameView: MTKView {
    // Rendering
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!

    // World
    private let world = World()
    private var chunkBuffers: [SIMD2<Int>: (buffer: MTLBuffer, vertexCount: Int)] = [:]

    // Player
    private let camera = Camera()

    // Input
    private var keysDown = Set<UInt16>()
    private var mouseCaptured: Bool = false

    // Timing
    private var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    private var frameCount: Int = 0
    private var fpsAccumTime: Double = 0

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        self.delegate = self
        setupMetal()
        loadWorld()
    }

    required init(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Setup

    private func setupMetal() {
        guard let device = self.device else { fatalError("No Metal device") }
        commandQueue = device.makeCommandQueue()

        let library: MTLLibrary
        do {
            // Load shader source from SwiftPM resource bundle
            let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal", subdirectory: "Shaders")
                ?? Bundle.module.url(forResource: "Shaders", withExtension: "metal")
            guard let url = url, let src = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("Could not locate Shaders.metal in bundle")
            }
            library = try device.makeLibrary(source: src, options: nil)
        } catch {
            fatalError("Shader compile failed: \(error)")
        }

        let vfn = library.makeFunction(name: "vs_main")!
        let ffn = library.makeFunction(name: "fs_main")!

        // SIMD3<Float> in Swift has 16-byte alignment, so Vertex layout is:
        //   position: offset 0
        //   normal:   offset 16
        //   color:    offset 32
        //   stride:   48
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = 16
        vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float3
        vd.attributes[2].offset = 32
        vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<Vertex>.stride
        vd.layouts[0].stepRate = 1
        vd.layouts[0].stepFunction = .perVertex

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = vfn
        pd.fragmentFunction = ffn
        pd.vertexDescriptor = vd
        pd.colorAttachments[0].pixelFormat = self.colorPixelFormat
        pd.depthAttachmentPixelFormat = self.depthStencilPixelFormat

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pd)
        } catch {
            fatalError("Pipeline state failed: \(error)")
        }

        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .less
        dd.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: dd)
    }

    private func loadWorld() {
        print("Generating world...")
        let t0 = CACurrentMediaTime()
        world.generate()
        let t1 = CACurrentMediaTime()
        print(String(format: "World generated in %.2fs", t1 - t0))

        rebuildChunkBuffers()
    }

    private func rebuildChunkBuffers() {
        guard let device = self.device else { return }
        chunkBuffers.removeAll()
        var totalVerts = 0
        for (coord, chunk) in world.chunks {
            if chunk.mesh.isEmpty { continue }
            let length = chunk.mesh.count * MemoryLayout<Vertex>.stride
            guard let buf = device.makeBuffer(bytes: chunk.mesh, length: length, options: .storageModeShared) else { continue }
            chunkBuffers[coord] = (buf, chunk.mesh.count)
            totalVerts += chunk.mesh.count
        }
        print("Loaded \(chunkBuffers.count) chunk buffers, \(totalVerts) total vertices.")
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)
        if event.keyCode == 53 { releaseMouse() }  // ESC
    }
    override func keyUp(with event: NSEvent) {
        keysDown.remove(event.keyCode)
    }

    override func mouseDown(with event: NSEvent) { captureMouse() }

    override func mouseMoved(with event: NSEvent) {
        handleMouseDelta(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }
    override func mouseDragged(with event: NSEvent) {
        handleMouseDelta(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }

    private func handleMouseDelta(dx: Float, dy: Float) {
        guard mouseCaptured else { return }
        let sens: Float = 0.0025
        camera.yaw   += dx * sens
        camera.pitch -= dy * sens
        let limit: Float = .pi / 2 - 0.01
        camera.pitch = max(-limit, min(limit, camera.pitch))
    }

    private func captureMouse() {
        if !mouseCaptured {
            NSCursor.hide()
            CGAssociateMouseAndMouseCursorPosition(0)
            mouseCaptured = true
        }
    }

    private func releaseMouse() {
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

    // MARK: - Update

    private func updatePlayer(dt: Float) {
        var move = Float3(0, 0, 0)
        // Apple key codes: W=13, S=1, A=0, D=2, Space=49, LShift=56, C=8
        if keysDown.contains(13) { move += camera.forward }
        if keysDown.contains(1)  { move -= camera.forward }
        if keysDown.contains(2)  { move += camera.right }
        if keysDown.contains(0)  { move -= camera.right }
        if keysDown.contains(49) { move += Float3(0, 1, 0) }
        if keysDown.contains(8)  { move -= Float3(0, 1, 0) }

        if length(move) > 0.0001 {
            move = normalize(move)
            let speed: Float = keysDown.contains(56) ? 30 : 12
            camera.position += move * speed * dt
        }
    }
}

// MARK: - MTKViewDelegate

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
            window?.title = String(format: "VoxelCraft M4 — %.0f FPS — pos (%.1f, %.1f, %.1f)",
                                   fps, camera.position.x, camera.position.y, camera.position.z)
            fpsAccumTime = 0
            frameCount = 0
        }

        updatePlayer(dt: dt)

        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
        var uniforms = Uniforms(
            viewProjection: camera.viewProjection(aspect: aspect),
            model: matrix_identity_float4x4,
            cameraPos: camera.position,
            lightDir: normalize(Float3(-0.4, -1.0, -0.3))
        )

        enc.setRenderPipelineState(pipelineState)
        enc.setDepthStencilState(depthState)
        enc.setCullMode(.back)
        enc.setFrontFacing(.counterClockwise)

        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

        for (_, entry) in chunkBuffers {
            enc.setVertexBuffer(entry.buffer, offset: 0, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: entry.vertexCount)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
}