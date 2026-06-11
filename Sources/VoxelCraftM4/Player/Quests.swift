import Foundation

enum QuestKind {
    case collect(BlockType, Int)   // Collect N of block type
    case place(BlockType, Int)     // Place N of block type
    case build(Int)                // Place a total of N blocks (any)
    case explore(Int)              // Walk N blocks total horizontal distance
    case reachHeight(Int)          // Reach Y >= N
}

final class Quest {
    let title: String
    let kind: QuestKind
    var progress: Int = 0
    let target: Int
    var completed: Bool { progress >= target }

    init(title: String, kind: QuestKind) {
        self.title = title
        self.kind = kind
        switch kind {
        case .collect(_, let n): target = n
        case .place(_, let n):   target = n
        case .build(let n):      target = n
        case .explore(let n):    target = n
        case .reachHeight(let n): target = n
        }
    }
}

final class QuestManager {
    private(set) var quests: [Quest] = []
    private(set) var totalScore: Int = 0

    init() {
        // Seed with a few starter quests (Minecraft-tutorial style)
        quests = [
            Quest(title: "Punch wood",        kind: .collect(.wood, 5)),
            Quest(title: "Gather grass blocks", kind: .collect(.grass, 8)),
            Quest(title: "Mine some stone",   kind: .collect(.stone, 16)),
            Quest(title: "Build something",   kind: .build(20)),
            Quest(title: "Explore 200 blocks",kind: .explore(200)),
            Quest(title: "Reach the peaks (y≥60)", kind: .reachHeight(60)),
            Quest(title: "Collect 4 leaves",  kind: .collect(.leaves, 4)),
            Quest(title: "Find sand (3+)",    kind: .collect(.sand, 3)),
        ]
    }

    /// Returns true if a quest just completed (so caller can show a toast).
    @discardableResult
    func onMined(_ type: BlockType) -> Quest? {
        var justDone: Quest? = nil
        for q in quests where !q.completed {
            if case .collect(let t, _) = q.kind, t == type {
                q.progress = min(q.target, q.progress + 1)
                if q.completed { totalScore += 50; justDone = q }
            }
        }
        return justDone
    }

    @discardableResult
    func onPlaced(_ type: BlockType) -> Quest? {
        var justDone: Quest? = nil
        for q in quests where !q.completed {
            switch q.kind {
            case .place(let t, _) where t == type:
                q.progress = min(q.target, q.progress + 1)
                if q.completed { totalScore += 50; justDone = q }
            case .build:
                q.progress = min(q.target, q.progress + 1)
                if q.completed { totalScore += 75; justDone = q }
            default: break
            }
        }
        return justDone
    }

    @discardableResult
    func onMoved(distance: Float) -> Quest? {
        var justDone: Quest? = nil
        for q in quests where !q.completed {
            if case .explore(let n) = q.kind {
                let prev = q.progress
                q.progress = min(n, prev + Int(distance.rounded()))
                if q.completed && prev < n { totalScore += 60; justDone = q }
            }
        }
        return justDone
    }

    @discardableResult
    func onHeight(_ y: Float) -> Quest? {
        var justDone: Quest? = nil
        for q in quests where !q.completed {
            if case .reachHeight(let n) = q.kind {
                let yi = Int(y)
                if yi > q.progress {
                    q.progress = min(n, yi)
                    if q.completed { totalScore += 80; justDone = q }
                }
            }
        }
        return justDone
    }
}