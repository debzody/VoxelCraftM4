import Foundation
import simd

enum CameraMode { case first, thirdBack, thirdFront }

final class Player {
    var position: Float3 = Float3(8, 60, 30)
    var velocity: Float3 = Float3(0, 0, 0)
    var yaw: Float = 0
    var pitch: Float = -0.4

    // AABB body dimensions (in blocks)
    static let halfWidth: Float = 0.3
    static let height: Float = 1.8
    static let eyeHeight: Float = 1.65

    // Physics
    var onGround: Bool = false
    var flying: Bool = false        // Toggle with F (default off — gravity ON)
    var fallDistance: Float = 0     // Tracks how far we've fallen since leaving ground
    static let gravity: Float = 28
    static let jumpSpeed: Float = 9
    static let walkSpeed: Float = 5
    static let sprintSpeed: Float = 9
    static let flySpeed: Float = 18
    static let terminalFall: Float = 60

    // Health
    var health: Int = 20         // 20 HP (10 hearts) Minecraft-style
    var maxHealth: Int = 20
    var isDead: Bool { health <= 0 }
    var deathTimer: Float = 0    // when dead, count up to respawn

    // Camera
    var cameraMode: CameraMode = .first
    var cameraDistance: Float = 4.0  // for third-person

    var forward: Float3 {
        Float3(cos(pitch) * sin(yaw), sin(pitch), -cos(pitch) * cos(yaw))
    }
    var right: Float3 { normalize(cross(forward, Float3(0, 1, 0))) }
    var eyePos: Float3 { Float3(position.x, position.y + Player.eyeHeight, position.z) }
    var bodyCenter: Float3 { Float3(position.x, position.y + Player.height * 0.5, position.z) }

    func cameraPos() -> Float3 {
        switch cameraMode {
        case .first: return eyePos
        case .thirdBack:
            // Camera behind player
            return eyePos - forward * cameraDistance
        case .thirdFront:
            return eyePos + forward * cameraDistance
        }
    }

    func cameraForward() -> Float3 {
        switch cameraMode {
        case .first, .thirdBack: return forward
        case .thirdFront: return -forward
        }
    }

    func viewMatrix() -> Float4x4 {
        let f = normalize(cameraForward())
        let r = normalize(cross(f, Float3(0, 1, 0)))
        let u = cross(r, f)
        let p = cameraPos()
        let t = Float3(-dot(r, p), -dot(u, p), dot(f, p))
        return Float4x4(columns: (
            SIMD4<Float>(r.x, u.x, -f.x, 0),
            SIMD4<Float>(r.y, u.y, -f.y, 0),
            SIMD4<Float>(r.z, u.z, -f.z, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)
        ))
    }

    func projectionMatrix(aspect: Float) -> Float4x4 {
        Math.perspective(fovyRadians: 75 * .pi / 180, aspect: aspect, near: 0.1, far: 1000)
    }

    func viewProjection(aspect: Float) -> Float4x4 {
        projectionMatrix(aspect: aspect) * viewMatrix()
    }

    // MARK: - Physics

    /// Check if AABB at given pos collides with any solid block.
    private func collides(at pos: Float3, world: World) -> Bool {
        let mn = Float3(pos.x - Player.halfWidth, pos.y, pos.z - Player.halfWidth)
        let mx = Float3(pos.x + Player.halfWidth, pos.y + Player.height, pos.z + Player.halfWidth)
        let x0 = Int(floor(mn.x)), x1 = Int(floor(mx.x - 0.0001))
        let y0 = Int(floor(mn.y)), y1 = Int(floor(mx.y - 0.0001))
        let z0 = Int(floor(mn.z)), z1 = Int(floor(mx.z - 0.0001))
        for x in x0...x1 {
            for y in y0...y1 {
                for z in z0...z1 {
                    if world.blockAt(x, y, z).isSolid { return true }
                }
            }
        }
        return false
    }

    /// Step physics: apply velocity, resolve per-axis collisions, gravity, fall damage.
    func physicsStep(dt: Float, wishDir: Float3, jump: Bool, sprinting: Bool, world: World) {
        if isDead {
            deathTimer += dt
            return
        }

        if flying {
            // Free-fly mode: ignore gravity
            let speed = Player.flySpeed
            position += wishDir * speed * dt
            velocity = Float3(0, 0, 0)
            return
        }

        // --- Horizontal movement ---
        let speed = sprinting ? Player.sprintSpeed : Player.walkSpeed
        let horiz = Float3(wishDir.x, 0, wishDir.z) * speed

        // Jump
        if jump && onGround {
            velocity.y = Player.jumpSpeed
            onGround = false
        }

        // Gravity
        velocity.y -= Player.gravity * dt
        if velocity.y < -Player.terminalFall { velocity.y = -Player.terminalFall }

        // Apply X
        var p = position
        p.x += horiz.x * dt
        if collides(at: p, world: world) { p.x = position.x }
        // Apply Z
        p.z += horiz.z * dt
        if collides(at: p, world: world) { p.z = position.z }
        // Apply Y
        let prevY = p.y
        p.y += velocity.y * dt
        if collides(at: p, world: world) {
            if velocity.y < 0 {
                onGround = true
                // Apply fall damage (capped) if accumulated
                if fallDistance > 4 {
                    let dmg = min(Int(fallDistance - 4), 12)  // cap at 12 HP per fall
                    if dmg > 0 { takeDamage(dmg) }
                }
                fallDistance = 0
            }
            velocity.y = 0
            p.y = prevY
        } else {
            if velocity.y < 0 {
                onGround = false
                fallDistance += abs(velocity.y) * dt
            } else {
                onGround = false
            }
        }

        position = p

        // Death pit
        if position.y < -10 {
            takeDamage(maxHealth)
        }
    }

    func takeDamage(_ amount: Int) {
        health = max(0, health - amount)
        if health <= 0 { deathTimer = 0 }
    }

    func respawn() {
        position = Float3(8, 60, 30)
        velocity = Float3(0, 0, 0)
        health = maxHealth
        deathTimer = 0
        fallDistance = 0
    }
}