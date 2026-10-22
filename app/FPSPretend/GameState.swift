import Foundation
import Observation

@MainActor @Observable
final class GameState {
    enum Phase { case title, game, resolution, result }
    let progress: ProgressStore
    private(set) var phase = Phase.title
    private(set) var stageIndex = 0
    private(set) var score = 0
    private(set) var remainingTime = 60
    private(set) var shotCount = 0
    private(set) var hitCount = 0
    private(set) var currentCombo = 0
    private(set) var maxCombo = 0
    private(set) var ammo = 18
    private(set) var hitFeedback = false
    private(set) var hitTargets: Set<Int> = []
    private(set) var targetHits: [Int] = []
    private(set) var variant = 0
    private(set) var message = ""
    private var pendingShot = false
    private var deadline = 0.0
    private var lastHit: Double?
    private var pausedAt: Double?
    private var resolutionUntil = 0.0
    var stage: Stage { Stage.all[stageIndex] }
    var resolvedCount: Int { targetHits.indices.filter { targetHits[$0] >= stage.hitsRequired(for: $0) }.count }
    var remainingWork: Int { max(0, stage.requiredHits - hitCount) }
    var progressFraction: Double { Double(hitCount) / Double(stage.requiredHits) }
    var progressText: String {
        let work = "残り\(remainingWork)回"
        return "\(work) ・ \(hitCount)/\(stage.requiredHits)"
    }
    var isCleared: Bool { !targetHits.isEmpty && resolvedCount == targetHits.count }
    var isFinalStage: Bool { stageIndex == Stage.all.count - 1 }
    var ending: String { stage.kind.details.endings[variant] }
    var accuracy: Int { shotCount == 0 ? 0 : Int(Double(hitCount) / Double(shotCount) * 100) }

    init(progress: ProgressStore? = nil) { self.progress = progress ?? ProgressStore() }

    @discardableResult func start(stageIndex: Int? = nil, now: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        let selected = stageIndex ?? progress.currentStage
        guard (0...progress.unlockedStage).contains(selected) else { return false }
        self.stageIndex = selected
        beginStage(now: now)
        return true
    }

    func advance(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard (phase == .result || phase == .resolution), isCleared, !isFinalStage else { return }
        stageIndex += 1
        beginStage(now: now)
    }

    func retry(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard phase == .result || phase == .resolution else { return }
        beginStage(now: now)
    }

    func continueFromResult(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard phase == .result || phase == .resolution else { return }
        if isCleared {
            if isFinalStage { start(stageIndex: 0, now: now) } else { advance(now: now) }
        } else { retry(now: now) }
    }

    func finishResolution() {
        guard phase == .resolution else { return }
        phase = .result
    }

    func returnToTitle() { phase = .title; hitFeedback = false }

    private func beginStage(now: Double) {
        score = 0
        remainingTime = stage.timeLimit
        shotCount = 0
        hitCount = 0
        currentCombo = 0
        maxCombo = 0
        ammo = 18
        pendingShot = false
        hitFeedback = false
        lastHit = nil
        hitTargets = []
        targetHits = Array(repeating: 0, count: stage.targets.count)
        variant = progress.beginVisit(stageIndex)
        message = stage.kind.details.instruction
        resolutionUntil = 0
        pausedAt = nil
        deadline = now + Double(stage.timeLimit)
        phase = .game
    }

    func tick(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard pausedAt == nil else { return }
        if phase == .resolution {
            if now >= resolutionUntil { phase = .result }
            return
        }
        guard phase == .game else { return }
        remainingTime = max(0, Int(ceil(deadline - now)))
        if let lastHit {
            hitFeedback = now - lastHit < 2
            if now - lastHit >= 2 { currentCombo = 0 }
        }
        if remainingTime == 0 {
            hitFeedback = false
            phase = .result
        }
    }

    func pause(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard (phase == .game || phase == .resolution), pausedAt == nil else { return }
        tick(now: now)
        if phase == .game || phase == .resolution { pausedAt = now }
    }

    func resume(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard let pausedAt else { return }
        let duration = max(0, now - pausedAt)
        deadline += duration
        resolutionUntil += duration
        if let lastHit { self.lastHit = lastHit + duration }
        self.pausedAt = nil
        tick(now: now)
    }

    // Validate the deadline on actions too, including the first frame after returning to the app.
    func fire(now: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        pendingShot = false
        tick(now: now)
        guard phase == .game, pausedAt == nil, ammo > 0 else { return false }
        ammo -= 1
        shotCount += 1
        pendingShot = true
        return true
    }

    @discardableResult func registerHit(targetID: Int = 0, now: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        tick(now: now)
        defer { pendingShot = false }
        guard phase == .game, pausedAt == nil, pendingShot, targetHits.indices.contains(targetID),
              targetHits[targetID] < stage.hitsRequired(for: targetID) else { return false }
        if let lastHit, now - lastHit >= 2 { currentCombo = 0 }
        score += 100
        hitCount += 1
        hitTargets.insert(targetID)
        targetHits[targetID] += 1
        currentCombo += 1
        maxCombo = max(maxCombo, currentCombo)
        lastHit = now
        hitFeedback = true
        let required = stage.hitsRequired(for: targetID)
        if targetHits[targetID] == required {
            message = stage.kind.completion(variant: variant)
            progress.discover(stage: stageIndex, ending: variant)
        } else {
            message = stage.kind.reaction(step: targetHits[targetID] * 4 / required)
        }
        if isCleared {
            progress.markCleared(stageIndex)
            hitFeedback = false
            resolutionUntil = now + 2.2
            phase = .resolution
        }
        return true
    }

    func reload(now: Double = ProcessInfo.processInfo.systemUptime) {
        tick(now: now)
        guard phase == .game, pausedAt == nil else { return }
        ammo = 18
    }
}
