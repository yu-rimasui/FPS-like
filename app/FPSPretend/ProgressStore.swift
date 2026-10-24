import Foundation
import Observation

@MainActor @Observable
final class ProgressStore {
    private let defaults: UserDefaults
    private(set) var cleared: Set<Int>
    private(set) var seen: Set<Int>
    private(set) var endings: Set<String>
    private var visits: [Int]
    private(set) var currentStage: Int

    var unlockedStage: Int { min(Stage.all.count - 1, (cleared.max() ?? -1) + 1) }
    var seenMotions: Set<EnemyMotion> {
        Set(seen.flatMap { Stage.all[$0].motions.map(\.collectionMotion) })
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loadedCleared = Set((defaults.array(forKey: "progress.cleared") as? [Int] ?? []).filter { Stage.all.indices.contains($0) })
        cleared = loadedCleared
        seen = Set((defaults.array(forKey: "progress.seen") as? [Int] ?? []).filter { Stage.all.indices.contains($0) })
        let validEndings = Set(Stage.all.indices.flatMap { stage in (0..<3).map { "\(stage):\($0)" } })
        endings = Set(defaults.stringArray(forKey: "progress.endings") ?? []).intersection(validEndings)
        let loadedVisits = (defaults.array(forKey: "progress.visits") as? [Int] ?? []).map { max(0, $0) }
        visits = Array((loadedVisits + Array(repeating: 0, count: Stage.all.count)).prefix(Stage.all.count))
        currentStage = min(max(0, defaults.integer(forKey: "progress.current")), min(Stage.all.count - 1, (loadedCleared.max() ?? -1) + 1))
    }

    func beginVisit(_ stage: Int) -> Int {
        guard (0...unlockedStage).contains(stage) else { return 0 }
        let variant = visits[stage] % 3
        visits[stage] = (visits[stage] % 3) + 1
        currentStage = stage
        seen.insert(stage)
        defaults.set(visits, forKey: "progress.visits")
        defaults.set(stage, forKey: "progress.current")
        defaults.set(seen.sorted(), forKey: "progress.seen")
        return variant
    }

    func discover(stage: Int, ending: Int) {
        guard Stage.all.indices.contains(stage), (0..<3).contains(ending) else { return }
        endings.insert("\(stage):\(ending)")
        defaults.set(endings.sorted(), forKey: "progress.endings")
    }

    func markCleared(_ stage: Int) {
        guard (0...unlockedStage).contains(stage) else { return }
        cleared.insert(stage)
        currentStage = min(Stage.all.count - 1, stage + 1)
        defaults.set(cleared.sorted(), forKey: "progress.cleared")
        defaults.set(currentStage, forKey: "progress.current")
    }
}
