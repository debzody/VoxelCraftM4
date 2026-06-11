import Foundation

/// Player inventory: maps each BlockType to a count.
/// Hotbar shows the 9 most relevant types.
final class Inventory {
    /// Counts per block type (only solid/placeable types).
    private(set) var counts: [BlockType: Int] = [:]

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