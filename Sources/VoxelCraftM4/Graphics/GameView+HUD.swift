import Foundation
import Metal
import simd

/// 2D HUD vertex (NDC position + color RGBA).
struct HUDVertex {
    var position: SIMD2<Float>   // NDC: -1..1
    var color: SIMD4<Float>      // RGBA
}

extension GameView {

    /// Rebuild the HUD: a crosshair plus the hotbar.
    /// Note: this uses NDC coordinates (-1..1). For better aspect handling we draw
    /// the hotbar bigger horizontally (which is fine on a 1280x720 window).
    func rebuildHUD() {
        guard let device = self.device else { return }
        var v: [HUDVertex] = []

        // ---------- Crosshair (white +) ----------
        let cw: Float = 0.012   // half-width in NDC
        let ch: Float = 0.002   // half-thickness
        let crossColor = SIMD4<Float>(0.95, 0.95, 0.95, 0.85)
        // Hide crosshair when dead (red overlay instead)
        if !player.isDead {
            appendQuad(&v, x0: -cw, y0: -ch, x1:  cw, y1:  ch, color: crossColor)
            appendQuad(&v, x0: -ch, y0: -cw, x1:  ch, y1:  cw, color: crossColor)
        } else {
            // Red death overlay
            appendQuad(&v, x0: -1, y0: -1, x1: 1, y1: 1, color: SIMD4<Float>(0.7, 0.05, 0.05, 0.45))
        }

        // ---------- Health bar (above hotbar) ----------
        let hbX: Float = -0.30
        let hbY: Float = -0.78
        let hbW: Float = 0.60
        let hbH: Float = 0.04
        // Bar background
        appendQuad(&v, x0: hbX - 0.01, y0: hbY - 0.01,
                       x1: hbX + hbW + 0.01, y1: hbY + hbH + 0.01,
                       color: SIMD4<Float>(0, 0, 0, 0.55))
        // Filled portion based on health
        let frac = Float(player.health) / Float(player.maxHealth)
        let fillColor: SIMD4<Float> = frac > 0.5 ?
            SIMD4<Float>(0.85, 0.15, 0.20, 0.95) :   // red heart
            SIMD4<Float>(0.95, 0.45, 0.10, 0.95)     // orange when low
        appendQuad(&v, x0: hbX, y0: hbY, x1: hbX + hbW * max(0, frac), y1: hbY + hbH, color: fillColor)
        // 10 segment ticks
        for i in 1..<10 {
            let tx = hbX + hbW * Float(i) / 10.0
            appendQuad(&v, x0: tx - 0.0015, y0: hbY, x1: tx + 0.0015, y1: hbY + hbH,
                       color: SIMD4<Float>(0, 0, 0, 0.6))
        }

        // ---------- Hotbar ----------
        let slotCount = hotbar.count
        let slotSize: Float = 0.07
        let slotGap: Float = 0.012
        let totalW = Float(slotCount) * slotSize + Float(slotCount - 1) * slotGap
        let startX: Float = -totalW * 0.5
        let baseY: Float = -0.92

        // Background panel
        let panelPadding: Float = 0.02
        appendQuad(&v,
                   x0: startX - panelPadding, y0: baseY - panelPadding,
                   x1: startX + totalW + panelPadding, y1: baseY + slotSize + panelPadding,
                   color: SIMD4<Float>(0, 0, 0, 0.45))

        for i in 0..<slotCount {
            let x = startX + Float(i) * (slotSize + slotGap)
            let y = baseY
            // Slot bg
            let isSel = (i == hotbarIndex)
            let bg: SIMD4<Float> = isSel ? SIMD4<Float>(1, 1, 1, 0.85) : SIMD4<Float>(0.2, 0.2, 0.25, 0.6)
            appendQuad(&v, x0: x, y0: y, x1: x + slotSize, y1: y + slotSize, color: bg)

            // Inner inset = block color
            let inset: Float = 0.012
            let bc = hotbar[i].color(face: 2) // top color
            let blockColor = SIMD4<Float>(bc.x, bc.y, bc.z, 1.0)
            appendQuad(&v,
                       x0: x + inset, y0: y + inset,
                       x1: x + slotSize - inset, y1: y + slotSize - inset,
                       color: blockColor)

            // Selection ring (yellow border) for active slot
            if isSel {
                let bw: Float = 0.005
                let ring = SIMD4<Float>(1.0, 0.85, 0.2, 1.0)
                // top
                appendQuad(&v, x0: x - bw, y0: y + slotSize - bw, x1: x + slotSize + bw, y1: y + slotSize + bw, color: ring)
                // bottom
                appendQuad(&v, x0: x - bw, y0: y - bw, x1: x + slotSize + bw, y1: y + bw, color: ring)
                // left
                appendQuad(&v, x0: x - bw, y0: y - bw, x1: x + bw, y1: y + slotSize + bw, color: ring)
                // right
                appendQuad(&v, x0: x + slotSize - bw, y0: y - bw, x1: x + slotSize + bw, y1: y + slotSize + bw, color: ring)
            }
        }

        hudVertexCount = v.count
        let length = v.count * MemoryLayout<HUDVertex>.stride
        hudBuffer = device.makeBuffer(bytes: v, length: length, options: .storageModeShared)
    }

    private func appendQuad(_ v: inout [HUDVertex],
                            x0: Float, y0: Float, x1: Float, y1: Float,
                            color: SIMD4<Float>) {
        let a = HUDVertex(position: SIMD2<Float>(x0, y0), color: color)
        let b = HUDVertex(position: SIMD2<Float>(x1, y0), color: color)
        let c = HUDVertex(position: SIMD2<Float>(x1, y1), color: color)
        let d = HUDVertex(position: SIMD2<Float>(x0, y1), color: color)
        v.append(a); v.append(b); v.append(c)
        v.append(a); v.append(c); v.append(d)
    }
}