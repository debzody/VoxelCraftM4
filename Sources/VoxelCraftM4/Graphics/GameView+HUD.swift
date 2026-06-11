import Foundation
import Metal
import simd

/// 2D HUD vertex (NDC position + color RGBA).
struct HUDVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

/// Tiny 3x5 bitmap font (digits 0–9). 1 = filled pixel.
private let digitGlyphs: [[UInt8]] = [
    // 0
    [0b111, 0b101, 0b101, 0b101, 0b111],
    // 1
    [0b010, 0b110, 0b010, 0b010, 0b111],
    // 2
    [0b111, 0b001, 0b111, 0b100, 0b111],
    // 3
    [0b111, 0b001, 0b111, 0b001, 0b111],
    // 4
    [0b101, 0b101, 0b111, 0b001, 0b001],
    // 5
    [0b111, 0b100, 0b111, 0b001, 0b111],
    // 6
    [0b111, 0b100, 0b111, 0b101, 0b111],
    // 7
    [0b111, 0b001, 0b001, 0b010, 0b010],
    // 8
    [0b111, 0b101, 0b111, 0b101, 0b111],
    // 9
    [0b111, 0b101, 0b111, 0b001, 0b111],
]

extension GameView {

    func rebuildHUD() {
        guard let device = self.device else { return }
        var v: [HUDVertex] = []

        // ---------- Crosshair ----------
        let cw: Float = 0.012, ch: Float = 0.002
        let crossColor = SIMD4<Float>(0.95, 0.95, 0.95, 0.9)
        if !player.isDead {
            appendQuad(&v, x0: -cw, y0: -ch, x1:  cw, y1:  ch, color: crossColor)
            appendQuad(&v, x0: -ch, y0: -cw, x1:  ch, y1:  cw, color: crossColor)
        } else {
            appendQuad(&v, x0: -1, y0: -1, x1: 1, y1: 1, color: SIMD4<Float>(0.7, 0.05, 0.05, 0.45))
        }

        // ---------- Health bar ----------
        let hbX: Float = -0.30, hbY: Float = -0.78, hbW: Float = 0.60, hbH: Float = 0.04
        appendQuad(&v, x0: hbX - 0.01, y0: hbY - 0.01,
                       x1: hbX + hbW + 0.01, y1: hbY + hbH + 0.01,
                       color: SIMD4<Float>(0, 0, 0, 0.55))
        let frac = Float(player.health) / Float(player.maxHealth)
        let fillColor: SIMD4<Float> = frac > 0.5 ?
            SIMD4<Float>(0.85, 0.15, 0.20, 0.95) :
            SIMD4<Float>(0.95, 0.45, 0.10, 0.95)
        appendQuad(&v, x0: hbX, y0: hbY, x1: hbX + hbW * max(0, frac), y1: hbY + hbH, color: fillColor)
        for i in 1..<10 {
            let tx = hbX + hbW * Float(i) / 10.0
            appendQuad(&v, x0: tx - 0.0015, y0: hbY, x1: tx + 0.0015, y1: hbY + hbH,
                       color: SIMD4<Float>(0, 0, 0, 0.6))
        }

        // ---------- Hotbar ----------
        let slotCount = hotbar.count
        let slotSize: Float = 0.08
        let slotGap: Float = 0.012
        let totalW = Float(slotCount) * slotSize + Float(slotCount - 1) * slotGap
        let startX: Float = -totalW * 0.5
        let baseY: Float = -0.93
        let panelPad: Float = 0.02
        appendQuad(&v,
                   x0: startX - panelPad, y0: baseY - panelPad,
                   x1: startX + totalW + panelPad, y1: baseY + slotSize + panelPad,
                   color: SIMD4<Float>(0, 0, 0, 0.55))

        for i in 0..<slotCount {
            let x = startX + Float(i) * (slotSize + slotGap)
            let y = baseY
            let isSel = (i == hotbarIndex)
            let bg: SIMD4<Float> = isSel ? SIMD4<Float>(1, 1, 1, 0.85) : SIMD4<Float>(0.2, 0.2, 0.25, 0.65)
            appendQuad(&v, x0: x, y0: y, x1: x + slotSize, y1: y + slotSize, color: bg)

            let inset: Float = 0.012
            let bc = hotbar[i].color(face: 2)
            let blockColor = SIMD4<Float>(bc.x, bc.y, bc.z, 1.0)
            appendQuad(&v,
                       x0: x + inset, y0: y + inset,
                       x1: x + slotSize - inset, y1: y + slotSize - inset,
                       color: blockColor)

            // Selected ring
            if isSel {
                let bw: Float = 0.005
                let ring = SIMD4<Float>(1.0, 0.85, 0.2, 1.0)
                appendQuad(&v, x0: x - bw, y0: y + slotSize - bw, x1: x + slotSize + bw, y1: y + slotSize + bw, color: ring)
                appendQuad(&v, x0: x - bw, y0: y - bw,            x1: x + slotSize + bw, y1: y + bw, color: ring)
                appendQuad(&v, x0: x - bw, y0: y - bw,            x1: x + bw,            y1: y + slotSize + bw, color: ring)
                appendQuad(&v, x0: x + slotSize - bw, y0: y - bw, x1: x + slotSize + bw, y1: y + slotSize + bw, color: ring)
            }

            // Slot number 1..7 (top-left)
            drawDigit(&v, digit: i + 1,
                      x: x + 0.005, y: y + slotSize - 0.022,
                      pixel: 0.0034,
                      color: SIMD4<Float>(1, 1, 0.6, 0.95))

            // Inventory count (bottom-right)
            let cnt = inventory.count(of: hotbar[i])
            if cnt > 0 {
                drawNumber(&v, value: cnt,
                           xRight: x + slotSize - 0.005, y: y + 0.005,
                           pixel: 0.0036,
                           color: SIMD4<Float>(1, 1, 1, 1))
            }
        }

        // ---------- Inventory drawer (left side) ----------
        // Show ALL collected blocks even if not on hotbar
        let invItems = inventory.counts.sorted { $0.key.rawValue < $1.key.rawValue }
        if !invItems.isEmpty {
            let invX: Float = -0.97
            var invY: Float = 0.85
            let invW: Float = 0.18
            let cellH: Float = 0.06
            // Panel
            let panelH: Float = Float(invItems.count) * cellH + 0.04
            appendQuad(&v, x0: invX - 0.01, y0: invY - panelH + 0.04,
                       x1: invX + invW, y1: invY + 0.04,
                       color: SIMD4<Float>(0, 0, 0, 0.55))
            for (type, count) in invItems {
                // Color swatch
                let bc = type.color(face: 2)
                appendQuad(&v, x0: invX + 0.005, y0: invY - 0.01,
                           x1: invX + 0.05, y1: invY + 0.035,
                           color: SIMD4<Float>(bc.x, bc.y, bc.z, 1))
                // Count
                drawNumber(&v, value: count,
                           xRight: invX + invW - 0.005, y: invY - 0.005,
                           pixel: 0.0036,
                           color: SIMD4<Float>(1, 1, 1, 1))
                invY -= cellH
            }
        }

        // Big SCORE display (top-left, very visible)
        let scoreLabelX: Float = -0.97
        let scoreLabelY: Float = 0.95
        // Background plate
        appendQuad(&v, x0: scoreLabelX - 0.01, y0: scoreLabelY - 0.07,
                   x1: scoreLabelX + 0.36, y1: scoreLabelY + 0.02,
                   color: SIMD4<Float>(0, 0, 0, 0.65))
        // "SCORE" letters drawn as colored rect markers + the actual digits
        // Tag bar (gold)
        appendQuad(&v, x0: scoreLabelX, y0: scoreLabelY - 0.005,
                   x1: scoreLabelX + 0.10, y1: scoreLabelY + 0.005,
                   color: SIMD4<Float>(1.0, 0.85, 0.20, 1.0))
        // Big number — pixel size 0.008 (much larger than slots)
        drawNumber(&v, value: quests.totalScore,
                   xRight: scoreLabelX + 0.34, y: scoreLabelY - 0.06,
                   pixel: 0.0090,
                   color: SIMD4<Float>(1.0, 0.95, 0.30, 1.0))

        // Quest panel + toast
        appendQuestUI(&v)

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

    /// Draw a single digit (0-9) starting at (x,y), each "pixel" is a quad of size `pixel`.
    fileprivate func drawDigit(_ v: inout [HUDVertex], digit: Int, x: Float, y: Float, pixel: Float, color: SIMD4<Float>) {
        guard digit >= 0 && digit <= 9 else { return }
        let glyph = digitGlyphs[digit]
        for row in 0..<5 {
            let bits = glyph[row]
            for col in 0..<3 {
                if (bits & UInt8(1 << (2 - col))) != 0 {
                    let px = x + Float(col) * pixel
                    let py = y - Float(row) * pixel
                    appendQuad(&v, x0: px, y0: py, x1: px + pixel, y1: py + pixel, color: color)
                }
            }
        }
    }

    /// Draw a multi-digit number right-aligned at xRight.
    fileprivate func drawNumber(_ v: inout [HUDVertex], value: Int, xRight: Float, y: Float, pixel: Float, color: SIMD4<Float>) {
        var n = max(0, value)
        var digits: [Int] = []
        if n == 0 {
            digits = [0]
        } else {
            while n > 0 {
                digits.append(n % 10); n /= 10
            }
        }
        // Each digit is 3 pixels wide + 1 pixel gap
        let digitW = pixel * 3
        let gap = pixel
        var x = xRight
        for d in digits {
            x -= digitW
            // Black shadow
            drawDigit(&v, digit: d, x: x + pixel * 0.3, y: y - pixel * 0.3, pixel: pixel,
                      color: SIMD4<Float>(0, 0, 0, color.w * 0.7))
            drawDigit(&v, digit: d, x: x, y: y, pixel: pixel, color: color)
            x -= gap
        }
    }
}
// MARK: - Quest panel & toast (overlay) — call from rebuildHUD by extending it

extension GameView {

    /// Append quest UI to the existing HUD vertex buffer.
    /// Called automatically inside rebuildHUD via this swizzle pattern.
    func appendQuestUI(_ v: inout [HUDVertex]) {
        // ===== Quest panel (top-right) =====
        let panelW: Float = 0.42
        let lineH: Float  = 0.045
        let activeQuests = quests.quests.prefix(6)
        let panelH = Float(activeQuests.count) * lineH + 0.06
        let px: Float = 1.0 - panelW - 0.02
        let py: Float = 1.0 - 0.04           // top y of panel

        appendHUDQuad(&v, x0: px, y0: py - panelH, x1: px + panelW, y1: py,
                      color: SIMD4<Float>(0, 0, 0, 0.55))
        // Title bar
        appendHUDQuad(&v, x0: px, y0: py - 0.04, x1: px + panelW, y1: py,
                      color: SIMD4<Float>(0.15, 0.30, 0.50, 0.90))

        // Score (top-right of title bar)
        drawHUDNumber(&v, value: quests.totalScore,
                      xRight: px + panelW - 0.01, y: py - 0.035, pixel: 0.0040,
                      color: SIMD4<Float>(1, 0.85, 0.25, 1))

        // Quest rows
        for (i, q) in activeQuests.enumerated() {
            let rowY = py - 0.04 - Float(i + 1) * lineH + lineH * 0.5
            // Status dot (filled if completed)
            let dotColor: SIMD4<Float> = q.completed ?
                SIMD4<Float>(0.25, 0.95, 0.30, 1) :
                SIMD4<Float>(0.6, 0.6, 0.6, 0.7)
            appendHUDQuad(&v, x0: px + 0.012, y0: rowY - 0.012,
                              x1: px + 0.028, y1: rowY + 0.012,
                              color: dotColor)
            // Progress bar
            let pbX = px + 0.038, pbW = panelW - 0.10, pbY = rowY - 0.014, pbH: Float = 0.026
            appendHUDQuad(&v, x0: pbX, y0: pbY, x1: pbX + pbW, y1: pbY + pbH,
                          color: SIMD4<Float>(0.10, 0.10, 0.15, 0.85))
            let frac = Float(q.progress) / Float(q.target)
            let barColor: SIMD4<Float> = q.completed
                ? SIMD4<Float>(0.20, 0.85, 0.30, 0.95)
                : SIMD4<Float>(0.30, 0.65, 0.95, 0.92)
            if frac > 0 {
                appendHUDQuad(&v, x0: pbX, y0: pbY,
                              x1: pbX + pbW * min(1, frac), y1: pbY + pbH,
                              color: barColor)
            }
            // Progress numbers (right side: progress/target)
            drawHUDNumber(&v, value: q.progress, xRight: pbX + pbW - 0.018, y: pbY + 0.005,
                          pixel: 0.0028, color: SIMD4<Float>(1,1,1,1))
            drawHUDNumber(&v, value: q.target, xRight: px + panelW - 0.012, y: pbY + 0.005,
                          pixel: 0.0028, color: SIMD4<Float>(0.85, 0.85, 0.95, 0.9))
            // small "/" between
            appendHUDQuad(&v, x0: pbX + pbW - 0.011, y0: pbY + 0.007,
                          x1: pbX + pbW - 0.008, y1: pbY + 0.020,
                          color: SIMD4<Float>(0.85, 0.85, 0.95, 0.9))
        }

        // ===== Toast (top-center) =====
        if toastTimer > 0 && !toastMessage.isEmpty {
            let alpha = min(1.0, toastTimer / 0.5)  // fade out last 0.5s
            let tH: Float = 0.07, tW: Float = 0.7
            let tX = -tW * 0.5, tY: Float = 0.85
            appendHUDQuad(&v, x0: tX, y0: tY, x1: tX + tW, y1: tY + tH,
                          color: SIMD4<Float>(0.10, 0.45, 0.20, 0.85 * alpha))
            // We don't have proper text rendering for messages; draw a green pulse bar.
            appendHUDQuad(&v, x0: tX + 0.01, y0: tY + 0.005,
                          x1: tX + tW - 0.01, y1: tY + 0.012,
                          color: SIMD4<Float>(0.95, 1.0, 0.5, 0.95 * alpha))
        }
    }

    /// Helper bridge — calls into the private `appendQuad` style so we don't duplicate code.
    fileprivate func appendHUDQuad(_ v: inout [HUDVertex],
                                   x0: Float, y0: Float, x1: Float, y1: Float,
                                   color: SIMD4<Float>) {
        let a = HUDVertex(position: SIMD2<Float>(x0, y0), color: color)
        let b = HUDVertex(position: SIMD2<Float>(x1, y0), color: color)
        let c = HUDVertex(position: SIMD2<Float>(x1, y1), color: color)
        let d = HUDVertex(position: SIMD2<Float>(x0, y1), color: color)
        v.append(a); v.append(b); v.append(c)
        v.append(a); v.append(c); v.append(d)
    }

    /// Right-aligned number for HUD overlays.
    fileprivate func drawHUDNumber(_ v: inout [HUDVertex], value: Int, xRight: Float, y: Float,
                                   pixel: Float, color: SIMD4<Float>) {
        var n = max(0, value)
        var digits: [Int] = []
        if n == 0 { digits = [0] }
        else { while n > 0 { digits.append(n % 10); n /= 10 } }
        let digitW = pixel * 3
        let gap = pixel
        var x = xRight
        for d in digits {
            x -= digitW
            drawHUDDigit(&v, digit: d, x: x, y: y, pixel: pixel, color: color)
            x -= gap
        }
    }

    fileprivate func drawHUDDigit(_ v: inout [HUDVertex], digit: Int, x: Float, y: Float,
                                  pixel: Float, color: SIMD4<Float>) {
        guard digit >= 0 && digit <= 9 else { return }
        // Reuse our private digitGlyphs through a quick local copy
        let glyphs: [[UInt8]] = [
            [0b111, 0b101, 0b101, 0b101, 0b111],
            [0b010, 0b110, 0b010, 0b010, 0b111],
            [0b111, 0b001, 0b111, 0b100, 0b111],
            [0b111, 0b001, 0b111, 0b001, 0b111],
            [0b101, 0b101, 0b111, 0b001, 0b001],
            [0b111, 0b100, 0b111, 0b001, 0b111],
            [0b111, 0b100, 0b111, 0b101, 0b111],
            [0b111, 0b001, 0b001, 0b010, 0b010],
            [0b111, 0b101, 0b111, 0b101, 0b111],
            [0b111, 0b101, 0b111, 0b001, 0b111],
        ]
        let glyph = glyphs[digit]
        for row in 0..<5 {
            let bits = glyph[row]
            for col in 0..<3 {
                if (bits & UInt8(1 << (2 - col))) != 0 {
                    let px = x + Float(col) * pixel
                    let py = y - Float(row) * pixel
                    appendHUDQuad(&v, x0: px, y0: py, x1: px + pixel, y1: py + pixel, color: color)
                }
            }
        }
    }
}
