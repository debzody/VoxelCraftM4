import Foundation

/// Player inventory: maps each BlockType to a count.
/// Hotbar shows the 9 most relevant types.
final class Inventory {
    /// Counts per block type (only solid/placeable types).
    private(set) var counts: [BlockType: Int] = [:]

    init() {
        // Starter inventory — player has 32 of each placeable block to start building right away
        counts[.grass]  = 32
        counts[.dirt]   = 32
        counts[.stone]  = 32
        counts[.sand]   = 32
        counts[.wood]   = 32
        counts[.leaves] = 32
        counts[.snow]   = 32
    }

    /// Add a block (called when player breaks one).
    func add(_ type: BlockType, _ amount: Int = 1) {
        guard type != .air else { return }
        counts[type, default: 0] += amount
    }

    /// Try to remove one block of the given type. Returns true if successful.
    @discardableResult
    func remove(_ type: BlockType, _ amount: Int = 1) -> Bool {
        let current = counts[type] ?? 0
        if current < amount { return false }
        counts[type] = current - amount
        if counts[type] == 0 { counts[type] = nil }
        return true
    }

    func count(of type: BlockType) -> Int {
        counts[type] ?? 0
    }
}