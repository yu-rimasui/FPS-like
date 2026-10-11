import Foundation
import Observation

@MainActor @Observable
final class GameState {
    enum Phase { case title, game, result }
    private(set) var phase = Phase.title
    private(set) var score = 0
    private(set) var remainingTime = 60
    private(set) var shotCount = 0
    private(set) var hitCount = 0
    private(set) var currentCombo = 0
    private(set) var maxCombo = 0
    private(set) var ammo = 18
    private(set) var hitFeedback = false
    private var deadline = 0.0
    private var lastHit: Double?
    var accuracy: Int { shotCount == 0 ? 0 : Int(Double(hitCount) / Double(shotCount) * 100) }

    func start(now: Double = ProcessInfo.processInfo.systemUptime) {
        score = 0
        remainingTime = 60
        shotCount = 0
        hitCount = 0
        currentCombo = 0
        maxCombo = 0
        ammo = 18
        hitFeedback = false
        lastHit = nil
        deadline = now + 60
        phase = .game
    }

    func tick(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard phase == .game else { return }
        remainingTime = max(0, Int(ceil(deadline - now)))
        if let lastHit {
            hitFeedback = now - lastHit < 0.35
            if now - lastHit >= 2 { currentCombo = 0 }
        }
        if remainingTime == 0 {
            hitFeedback = false
            phase = .result
        }
    }

    // Validate the deadline on actions too, including the first frame after returning to the app.
    func fire(now: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        tick(now: now)
        guard phase == .game, ammo > 0 else { return false }
        ammo -= 1
        shotCount += 1
        return true
    }

    func registerHit(now: Double = ProcessInfo.processInfo.systemUptime) {
        guard phase == .game else { return }
        if let lastHit, now - lastHit >= 2 { currentCombo = 0 }
        score += 100
        hitCount += 1
        currentCombo += 1
        maxCombo = max(maxCombo, currentCombo)
        lastHit = now
        hitFeedback = true
    }

    func reload(now: Double = ProcessInfo.processInfo.systemUptime) {
        tick(now: now)
        guard phase == .game else { return }
        ammo = 18
    }
}
