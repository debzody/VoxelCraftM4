# 🎮 VoxelCraft M4 — Starter

A Minecraft-like voxel game built in **Swift + Metal 3** for **Apple Silicon (M4 Pro)**.

This is the **starter scaffold** that already runs and shows a procedurally generated voxel world with a flying first-person camera. From here, work through `../PROJECT_PROMPT.md` to add PBR, ray-traced shadows, lighting, mobs, etc.

---

## ✅ What's already implemented

- Cocoa window + Metal 3 setup with **120 Hz ProMotion**
- **Procedural terrain** (multi-octave value noise heightmap, ~13×13 chunks)
- Block types: grass, dirt, stone, sand
- **Greedy-style face culling** (only visible cube faces are emitted)
- Per-face hemispherical ambient + diffuse lighting in MSL
- Distance fog + simple tonemap
- **First-person flying camera** (WASD + mouse-look)
- Live FPS + position in window title

## ▶️ Run

```bash
cd ~/Desktop/MinecraftClone_M4Pro/VoxelCraftM4
swift run -c release
```

First launch generates ~13×13 chunks (~30k–80k vertices). Generation takes <1s on M4 Pro.

## 🎮 Controls

| Key | Action |
|-----|--------|
| **Click in window** | Capture mouse / look around |
| **W A S D** | Move forward / left / back / right |
| **Space** | Fly up |
| **C** | Fly down |
| **Left Shift** | Sprint (2.5×) |
| **Esc** | Release mouse |
| **⌘Q** | Quit |

## 📁 Project Structure

```
VoxelCraftM4/
├── Package.swift
├── Sources/VoxelCraftM4/
│   ├── main.swift                 # Entry point
│   ├── Engine/
│   │   ├── AppDelegate.swift      # NSApp + window setup
│   │   └── Math.swift             # SIMD matrix helpers + Uniforms
│   ├── Graphics/
│   │   └── GameView.swift         # MTKView, renderer, input
│   ├── Player/
│   │   └── Camera.swift           # FPS camera (yaw/pitch)
│   ├── World/
│   │   ├── Block.swift            # BlockType enum + colors
│   │   ├── Chunk.swift            # Chunk data + mesh builder
│   │   ├── Noise.swift            # 2D value noise
│   │   └── World.swift            # Chunk container + opacity test
│   └── Resources/
│       └── Shaders/
│           └── Shaders.metal      # Vertex + fragment shaders
```

## 🔜 Next Steps (see PROJECT_PROMPT.md)

1. **Greedy meshing** — merge coplanar same-block faces → 5–10× fewer triangles
2. **Texture atlas** — replace per-face colors with sampled textures
3. **Block placing/breaking** — raycast + chunk re-meshing
4. **Day/night cycle + skybox**
5. **Hardware ray-traced shadows** (Metal `MTLAccelerationStructure`)
6. **Cave generation** (3D noise)
7. **Trees, water, biomes**
8. **MetalFX upscaling** for 4K @ 120 Hz

## 🛠 Building Issues?

- Requires **Xcode 15+** and **macOS 14+**.
- If you see "Could not locate Shaders.metal", clean `.build/` and rebuild — SwiftPM resource bundling sometimes lags on first build.
- Profile with: `xcrun xctrace record --template "Metal System Trace" --launch .build/release/VoxelCraftM4`

---

🚀 **Now go build the rest! Open `../PROJECT_PROMPT.md` for the full 12-phase roadmap.**