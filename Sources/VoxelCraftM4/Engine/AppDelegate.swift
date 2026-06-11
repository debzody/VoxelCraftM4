import Cocoa
import MetalKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var gameView: GameView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Build menu so the app can quit / show normally
        setupMenu()

        let frame = NSRect(x: 100, y: 100, width: 1280, height: 720)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoxelCraft M4 — Minecraft-like (Metal 3)"
        window.center()

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }

        gameView = GameView(frame: frame, device: device)
        gameView.preferredFramesPerSecond = 120 // ProMotion on M4 Pro
        gameView.colorPixelFormat = .bgra8Unorm_srgb
        gameView.depthStencilPixelFormat = .depth32Float
        gameView.clearColor = MTLClearColor(red: 0.62, green: 0.80, blue: 0.98, alpha: 1.0) // bright sky blue (matches fog)
        gameView.sampleCount = 1

        window.contentView = gameView
        window.makeFirstResponder(gameView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func setupMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quit = NSMenuItem(title: "Quit VoxelCraft M4",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        appMenu.addItem(quit)
        appMenuItem.submenu = appMenu

        NSApplication.shared.mainMenu = mainMenu
    }
}