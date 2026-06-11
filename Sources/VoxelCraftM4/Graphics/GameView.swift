import Cocoa
import Metal
import MetalKit
import simd

final class GameView: MTKView {
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var pipelineState2D: MTLRenderPipelineState!
    var depthState: MTLDepthStencilState!

    let world = World()
    var chunkBuffers: [SIMD2<Int>: (buffer: MTLBuffer, vertexCount: Int)] = [:]
    var cows: [Cow] = []
    var entityBuffer: MTLBuffer?
    var entityVertexCount: Int = 0
    var selectionBuffer: MTLBuffer?
    var selectionVertexCount: Int = 0
    var hudBuffer: MTLBuffer?
    var hudVertexCount: Int = 0

    let player = Player()
    let hotbar: [BlockType] = [.grass, .dirt, .stone, .sand, .wood, .leaves, .snow]
    var hotbarIndex: Int = 0

    var keysDown = Set<UInt16>()
    var mouseCaptured: Bool = false
    var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    var frameCount: Int = 0
    var fpsAccumTime: Double = 0

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        delegate = self
        setupMetal()
        loadWorld()
        spawnCows()
        rebuildEntityMesh()
        rebuildHUD()
    }
    required init(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    private func setupMetal() {
        guard let device = self.device else { fatalError("No Metal device") }
        commandQueue = device.makeCommandQueue()
        let lib: MTLLibrary
        do {
            let url = Bundle.module.url(forResource: "Shaders", withExtension: "metal", subdirectory: "Shaders")
                ?? Bundle.module.url(forResource: "Shaders", withExtension: "metal")
            guard let url = url, let src = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("Shaders.metal not found")
            }
            lib = try device.makeLibrary(source: src, options: nil)
        } catch { fatalError("Shader compile: \(error)") }

        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3; vd.attributes[0].offset = 0;  vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3; vd.attributes[1].offset = 16; vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float3; vd.attributes[2].offset = 32; vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<Vertex>.stride

        let pd = MTLRenderPipelineDescriptor()
        pd.vertexFunction = lib.makeFunction(name: "vs_main")
        pd.fragmentFunction = lib.makeFunction(name: "fs_main")
        pd.vertexDescriptor = vd
        pd.colorAttachments[0].pixelFormat = colorPixelFormat
        pd.depthAttachmentPixelFormat = depthStencilPixelFormat
        pipelineState = try! device.makeRenderPipelineState(descriptor: pd)

        let pd2 = MTLRenderPipelineDescriptor()
        pd2.vertexFunction = lib.makeFunction(name: "vs_hud")
        pd2.fragmentFunction = lib.makeFunction(name: "fs_hud")
        pd2.colorAttachments[0].pixelFormat = colorPixelFormat
        pd2.depthAttachmentPixelFormat = depthStencilPixelFormat
        pd2.colorAttachments[0].isBlendingEnabled = true
        pd2.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pd2.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineState2D = try! device.makeRenderPipelineState(descriptor: pd2)

        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .less
        dd.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: dd)
    }

    private func loadWorld() {
        print("Generating world...")
        let t0 = CACurrentMediaTime()
        world.generate()
        print(String(format: "World generated in %.2fs", CACurrentMediaTime() - t0))
        rebuildChunkBuffers()
        spawnPlayerOnTerrain()
    }

    private func spawnPlayerOnTerrain() {
        // Find a grass top near origin and drop player on it
        for r in 0..<30 {
            for x in -r...r {
                for z in -r...r {
                    if abs(x) != r && abs(z) != r { continue }
                    var y = Chunk.sizeY - 1
                    while y > 0 && world.blockAt(x, y, z) == .air { y -= 1 }
                    if world.blockAt(x, y, z) == .grass {
                        player.position = Float3(Float(x) + 0.5, Float(y + 1), Float(z) + 0.5)
                        player.velocity = Float3(0, 0, 0)
                        return
                    }
                }
            }
        }
    }

    func rebuildChunkBuffers() {
        guard let device = self.device else { return }
        chunkBuffers.removeAll()
        for (coord, chunk) in world.chunks where !chunk.mesh.isEmpty {
            let len = chunk.mesh.count * MemoryLayout<Vertex>.stride
            if let buf = device.makeBuffer(bytes: chunk.mesh, length: len, options: .storageModeShared) {
                chunkBuffers[coord] = (buf, chunk.mesh.count)
            }
        }
    }

    func rebuildOneChunk(_ coord: SIMD2<Int>) {
        guard let device = self.device, let chunk = world.chunks[coord] else { return }
        chunk.buildMesh(world: world)
        if chunk.mesh.isEmpty {
            chunkBuffers.removeValue(forKey: coord); return
        }
        let len = chunk.mesh.count * MemoryLayout<Vertex>.stride
        if let buf = device.makeBuffer(bytes: chunk.mesh, length: len, options: .storageModeShared) {
            chunkBuffers[coord] = (buf, chunk.mesh.count)
        }
    }
}