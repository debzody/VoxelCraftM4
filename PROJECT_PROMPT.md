# 🎮 VoxelCraft M4 - High-Graphics Minecraft-like Game for Mac M4 Pro

## 📋 Master Prompt

> **Build a high-performance, high-graphics voxel-based sandbox game (Minecraft-like) optimized specifically for Apple Silicon M4 Pro using Metal 3 API. The game should leverage the M4 Pro's unified memory architecture, hardware-accelerated ray tracing, and Neural Engine. Target 120 FPS at 4K resolution with stunning visuals including PBR materials, dynamic global illumination, volumetric clouds, realistic water with screen-space reflections, and procedurally generated infinite worlds.**

---

## 🎯 Project Goals

- **Platform**: macOS 14+ (Sonoma/Sequoia) on Apple Silicon (M4 Pro)
- **Performance**: 120 FPS @ 4K, < 8GB RAM usage
- **Graphics**: AAA-quality voxel rendering with ray-traced shadows
- **Gameplay**: Minecraft-style survival + creative modes
- **Language**: Swift + Metal Shading Language (MSL)
- **Engine**: Custom engine (no Unity/Unreal) for max performance

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ / Metal Shading Language |
| Graphics API | Metal 3 (with MetalFX upscaling) |
| Audio | AVFoundation + PHASE (spatial audio) |
| Physics | Custom voxel physics + SIMD |
| Networking | Network.framework (multiplayer) |
| Build System | Xcode 15+ / Swift Package Manager |
| Noise/Worldgen | Simplex/Perlin noise (Accelerate framework) |
| AI/NPCs | Core ML (Neural Engine) |

---

## ✅ Development Checklist

### Phase 1: Foundation & Setup
- [ ] Install Xcode 15+ and Command Line Tools
- [ ] Create Swift Package / Xcode project structure
- [ ] Set up Metal device, command queue, and render pipeline
- [ ] Configure ProMotion 120Hz display support
- [ ] Set up MetalKit view (MTKView) with proper drawable
- [ ] Implement basic game loop with CADisplayLink
- [ ] Create logging and profiling system (os_signpost)

### Phase 2: Core Rendering Engine
- [ ] Implement camera system (perspective, FPS controls)
- [ ] Create vertex/fragment shaders for voxel rendering
- [ ] Implement frustum culling
- [ ] Add depth buffer and depth testing
- [ ] Implement instanced rendering for blocks
- [ ] Create texture atlas system for block textures
- [ ] Add MSAA / TAA anti-aliasing
- [ ] Integrate MetalFX for upscaling (4K from 1440p)

### Phase 3: Voxel World System
- [ ] Design chunk system (16x16x256 blocks per chunk)
- [ ] Implement chunk mesh generation (greedy meshing algorithm)
- [ ] Add face culling (don't render hidden faces)
- [ ] Create block registry (dirt, stone, wood, water, etc.)
- [ ] Implement chunk loading/unloading based on player position
- [ ] Add multi-threaded chunk generation (GCD/async)
- [ ] Implement Level of Detail (LOD) for distant chunks
- [ ] Add chunk serialization (save/load to disk)

### Phase 4: World Generation
- [ ] Implement Perlin/Simplex noise (use Accelerate.framework)
- [ ] Create biome system (forest, desert, mountains, ocean, tundra)
- [ ] Add terrain generation with multiple noise octaves
- [ ] Generate caves (3D noise / cellular automata)
- [ ] Add ore distribution system
- [ ] Implement structure generation (trees, villages, dungeons)
- [ ] Add water and lava placement
- [ ] Create infinite world streaming

### Phase 5: Advanced Graphics (M4 Pro Showcase)
- [ ] Implement PBR (Physically Based Rendering) materials
- [ ] Add hardware ray-traced shadows (Metal Ray Tracing)
- [ ] Implement screen-space reflections (SSR) for water
- [ ] Add screen-space ambient occlusion (SSAO/HBAO)
- [ ] Create volumetric clouds (raymarched)
- [ ] Implement dynamic skybox with sun/moon cycle
- [ ] Add volumetric fog and god rays
- [ ] Implement bloom and HDR tonemapping (ACES)
- [ ] Add motion blur and depth of field
- [ ] Create particle system (rain, snow, smoke, sparks)
- [ ] Implement realistic water shader (waves, refraction, foam)
- [ ] Add dynamic global illumination (light propagation volumes)

### Phase 6: Player & Physics
- [ ] Implement first-person controller
- [ ] Add AABB voxel collision detection
- [ ] Create jumping, gravity, swimming mechanics
- [ ] Implement raycasting for block selection
- [ ] Add block breaking/placing logic
- [ ] Create inventory system
- [ ] Add hotbar UI
- [ ] Implement crafting system

### Phase 7: Lighting System
- [ ] Implement block light propagation (torches, lava)
- [ ] Add sky light propagation
- [ ] Create smooth lighting (ambient occlusion per vertex)
- [ ] Add colored lights support
- [ ] Implement day/night cycle with sun position

### Phase 8: Audio
- [ ] Set up AVAudioEngine
- [ ] Add 3D spatial audio with PHASE framework
- [ ] Implement footstep sounds (per block type)
- [ ] Add ambient sounds (wind, water, cave)
- [ ] Create block break/place sounds
- [ ] Add background music system

### Phase 9: Entities & AI
- [ ] Create entity system (ECS architecture)
- [ ] Add basic mobs (cow, pig, sheep, zombie, skeleton)
- [ ] Implement pathfinding (A* on voxel grid)
- [ ] Add mob AI behaviors (Core ML for advanced AI)
- [ ] Create combat system
- [ ] Add health/hunger mechanics

### Phase 10: UI/UX
- [ ] Create main menu
- [ ] Add settings menu (graphics, audio, controls)
- [ ] Implement in-game HUD (health, hunger, hotbar)
- [ ] Add inventory and crafting UI
- [ ] Create pause menu
- [ ] Add debug overlay (F3-style: FPS, coords, chunks)

### Phase 11: Save/Load & Performance
- [ ] Implement world save format (region files)
- [ ] Add player data persistence
- [ ] Profile with Instruments (Metal System Trace)
- [ ] Optimize draw calls (target < 1000)
- [ ] Implement GPU-driven rendering
- [ ] Add memory pool for chunk allocation
- [ ] Optimize for unified memory architecture

### Phase 12: Polish & Release
- [ ] Add particle effects polish
- [ ] Implement achievements
- [ ] Add controller support (PS5/Xbox via GameController.framework)
- [ ] Create installer / .app bundle
- [ ] Code sign and notarize for macOS
- [ ] Write README and documentation

---

## 🎨 Detailed Component Prompts (Copy-paste these into Cline/ChatGPT/Claude)

### Prompt 1: Project Initialization
```
Create a Swift Package Manager project named "VoxelCraftM4" with the following structure:
- Sources/VoxelCraftM4/Engine/ (rendering, math, ECS)
- Sources/VoxelCraftM4/World/ (chunks, generation, blocks)
- Sources/VoxelCraftM4/Player/ (controller, inventory)
- Sources/VoxelCraftM4/Graphics/ (shaders, materials)
- Sources/VoxelCraftM4/Audio/
- Sources/VoxelCraftM4/UI/
- Resources/Shaders/ (.metal files)
- Resources/Textures/
- Resources/Sounds/
Set deployment target to macOS 14.0, enable Metal 3 features.
```

### Prompt 2: Metal Renderer
```
Implement a Metal 3 renderer in Swift that:
- Initializes MTLDevice with highest performance preference
- Creates a triple-buffered command queue
- Sets up MTKView with .bgra8Unorm_srgb pixel format
- Configures ProMotion 120Hz with preferredFramesPerSecond
- Implements deferred rendering with G-buffer (albedo, normal, depth, material)
- Uses argument buffers for bindless textures
- Supports Metal Ray Tracing (MTLAccelerationStructure)
```

### Prompt 3: Voxel Chunk System
```
Design a chunk system with:
- Chunk size: 16x16x256 blocks (Minecraft standard)
- Use UInt16 for block IDs (65k block types)
- Implement greedy meshing to minimize triangle count
- Generate meshes on background queue using DispatchQueue
- Use SIMD3<Float> for positions
- Cache generated meshes in MTLBuffer (shared storage on Apple Silicon)
- Implement render distance up to 32 chunks
```

### Prompt 4: World Generation
```
Create a procedural world generator using:
- 4-octave Simplex noise for terrain heightmap
- 3D noise for caves with threshold function
- Biome map using temperature/humidity noise
- Voronoi cells for biome boundaries
- Tree placement using Poisson disk sampling
- Use vDSP/Accelerate for SIMD noise computation
- Seed-based deterministic generation
```

### Prompt 5: Advanced Shaders (MSL)
```
Write Metal shaders for:
1. Voxel vertex shader with instance transformation and AO
2. PBR fragment shader with: albedo, normal, roughness, metallic maps
3. Ray-traced shadow shader using intersection function tables
4. Atmospheric scattering shader (Rayleigh + Mie)
5. Volumetric cloud raymarching shader
6. Water shader with FFT waves and SSR
7. Post-processing chain: SSAO, bloom, ACES tonemap, FXAA/TAA
```

### Prompt 6: Performance Optimization
```
Optimize for M4 Pro:
- Use unified memory (storageMode = .shared) - no copying!
- Leverage Apple GPU Family 9 features
- Use mesh shaders for GPU-driven culling
- Tile-based deferred rendering (TBDR friendly)
- Function constants for shader specialization
- ICB (Indirect Command Buffers) for draw call reduction
- MetalFX upscaling: render at 1440p, upscale to 4K
- Use Neural Engine via Core ML for AI mob behaviors
```

### Prompt 7: Player Controller
```
Implement a first-person player controller in Swift:
- WASD movement, space to jump, shift to sprint
- Mouse look with NSEvent (lock cursor with CGAssociateMouseAndKeyboardEvent)
- Smooth acceleration/deceleration
- Crouch (Ctrl), fly toggle (double-space in creative)
- Raycast block selection (max 5 blocks distance)
- Left click = break, right click = place
- Hotbar slots 1-9, scroll wheel to change
```

### Prompt 8: World Save System
```
Create a region-based save format:
- Group 32x32 chunks per region file (.vcr extension)
- Use LZ4 compression (Apple's Compression framework)
- Async I/O with FileHandle
- Save player data as JSON in level.dat
- Auto-save every 5 minutes
- Atomic writes (write to temp, then rename)
```

---

## 🚀 Quick Start Commands

```bash
# Create project structure
mkdir -p ~/Desktop/MinecraftClone_M4Pro/VoxelCraftM4
cd ~/Desktop/MinecraftClone_M4Pro/VoxelCraftM4

# Initialize Swift Package
swift package init --type executable --name VoxelCraftM4

# Open in Xcode
open Package.swift

# Build & run
swift build -c release
swift run -c release

# Profile with Instruments
xcrun xctrace record --template "Metal System Trace" --launch .build/release/VoxelCraftM4
```

---

## 📚 Essential Resources

- **Apple Metal Docs**: https://developer.apple.com/metal/
- **Metal Sample Code**: https://developer.apple.com/metal/sample-code/
- **MetalFX**: https://developer.apple.com/documentation/metalfx
- **PHASE Audio**: https://developer.apple.com/documentation/phase
- **Minecraft Wiki (Tech)**: https://minecraft.wiki/w/Java_Edition_level_format
- **Greedy Meshing**: https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/
- **PBR Guide**: https://google.github.io/filament/Filament.html
- **Ray Tracing Gems**: https://www.realtimerendering.com/raytracinggems/

---

## ⚡ M4 Pro-Specific Tips

1. **Unified Memory**: Use `.storageModeShared` for ALL buffers - zero copy CPU↔GPU
2. **Performance Cores**: Use `qos: .userInteractive` for render thread
3. **Efficiency Cores**: Use `qos: .utility` for chunk generation
4. **Neural Engine**: Run AI inference via Core ML with `.cpuAndNeuralEngine`
5. **Hardware RT**: M4 Pro has hardware ray tracing - use it for shadows!
6. **Mesh Shaders**: M4 supports mesh shaders - perfect for voxel culling
7. **120Hz ProMotion**: Set `preferredFramesPerSecond = 120` on MTKView

---

## 🎯 Recommended Build Order (Week-by-Week)

| Week | Focus |
|------|-------|
| 1 | Phase 1-2: Setup & Basic Renderer |
| 2 | Phase 3: Chunk System & Meshing |
| 3 | Phase 4: World Generation |
| 4 | Phase 6: Player Controller & Physics |
| 5 | Phase 7: Lighting System |
| 6-7 | Phase 5: Advanced Graphics (PBR, RT) |
| 8 | Phase 8-9: Audio & Entities |
| 9 | Phase 10: UI/UX |
| 10 | Phase 11: Save/Load & Optimization |
| 11-12 | Phase 12: Polish & Release |

---

## 🏁 START HERE

**Step 1**: Open Terminal and run the Quick Start Commands above.

**Step 2**: Use **Prompt 1** with Cline (or your AI assistant) to scaffold the project.

**Step 3**: Work through each phase sequentially. Use the corresponding prompt for each major component.

**Step 4**: Check off items in this checklist as you complete them.

Good luck building VoxelCraft M4! 🚀
