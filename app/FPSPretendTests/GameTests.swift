import XCTest
import RealityKit
import SwiftUI
@testable import FPSPretend

final class GameTests: XCTestCase {
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        suites = []
        super.tearDown()
    }

    private func defaults() throws -> UserDefaults {
        let suite = "FPSDailyTests.\(UUID().uuidString)"
        suites.append(suite)
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    @MainActor func testProgressAndCollectionSurviveInterruptionAndRetry() throws {
        let storage = try defaults()
        let progress = ProgressStore(defaults: storage)
        let state = GameState(progress: progress)
        XCTAssertFalse(state.start(stageIndex: 1, now: 10))
        XCTAssertTrue(state.start(stageIndex: 0, now: 10))
        XCTAssertEqual(state.variant, 0)
        XCTAssertTrue(state.fire(now: 11))
        XCTAssertTrue(state.registerHit(targetID: 0, now: 11))
        state.tick(now: 12.5)
        XCTAssertTrue(state.hitFeedback, "The punchline must remain visible long enough to read")
        XCTAssertFalse(state.registerHit(targetID: 0, now: 11), "A solved enemy cannot be scored twice")
        XCTAssertEqual(state.score, 100)
        state.returnToTitle()
        let restored = ProgressStore(defaults: storage)
        XCTAssertTrue(restored.seen.contains(0))
        XCTAssertTrue(restored.endings.contains("0:0"))
        XCTAssertEqual(restored.unlockedStage, 0)
        state.start(stageIndex: 0, now: 100)
        XCTAssertEqual(state.variant, 1)
        state.tick(now: 135)
        XCTAssertFalse(state.isCleared)
        state.continueFromResult(now: 140)
        XCTAssertEqual(state.variant, 2)
        XCTAssertTrue(progress.endings.contains("0:0"))
        for target in state.targetHits.indices {
            XCTAssertTrue(state.fire(now: 141))
            XCTAssertTrue(state.registerHit(targetID: target, now: 141))
        }
        XCTAssertEqual(state.phase, .resolution)
        XCTAssertEqual(ProgressStore(defaults: storage).unlockedStage, 1, "A clear must be saved before the ending animation finishes")
        XCTAssertTrue(ProgressStore(defaults: storage).endings.contains("0:2"))
        state.tick(now: 144)
        state.continueFromResult(now: 145)
        XCTAssertEqual(state.stageIndex, 1)
        XCTAssertEqual(ProgressStore(defaults: storage).currentStage, 1)
    }

    @MainActor func testAllTenStagesResolveThenRestartWithoutLosingCollection() throws {
        let storage = try defaults()
        let progress = ProgressStore(defaults: storage)
        let state = GameState(progress: progress)
        XCTAssertEqual(Stage.all.count, 10)
        XCTAssertEqual(Set(Stage.all.map(\.kind)).count, 10)
        state.start(stageIndex: 0, now: 10)
        for (index, stage) in Stage.all.enumerated() {
            let now = Double(index) * 100 + 10
            XCTAssertEqual(state.stageIndex, index)
            XCTAssertTrue((30...60).contains(stage.timeLimit))
            for target in state.targetHits.indices {
                for _ in 0..<stage.kind.hitsToResolve {
                    if state.ammo == 0 { state.reload(now: now) }
                    XCTAssertTrue(state.fire(now: now))
                    XCTAssertTrue(state.registerHit(targetID: target, now: now))
                }
            }
            XCTAssertEqual(state.phase, .resolution)
            XCTAssertTrue(state.isCleared)
            XCTAssertEqual(state.resolvedCount, stage.targets.count)
            XCTAssertEqual(state.hitCount, stage.requiredHits)
            XCTAssertFalse(state.fire(now: now))
            state.continueFromResult(now: now)
            XCTAssertEqual(state.phase, .resolution)
            state.tick(now: now + 3)
            XCTAssertEqual(state.phase, .result)
            XCTAssertTrue(progress.cleared.contains(index))
            XCTAssertTrue(progress.endings.contains("\(index):0"))
            state.continueFromResult(now: now + 100)
        }
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.phase, .game)
        XCTAssertEqual(state.score, 0)
        let reloaded = ProgressStore(defaults: storage)
        XCTAssertEqual(reloaded.cleared.count, 10)
        XCTAssertEqual(reloaded.seen.count, 10)
        XCTAssertEqual(reloaded.endings.count, 10)
        XCTAssertEqual(reloaded.unlockedStage, 9)
        state.returnToTitle()
        XCTAssertEqual(state.phase, .title)
        XCTAssertTrue(state.start(stageIndex: 9))
    }

    @MainActor func testPauseDeadlineAmmoAndInvalidHits() throws {
        let state = GameState(progress: ProgressStore(defaults: try defaults()))
        XCTAssertFalse(state.fire(now: 0))
        state.start(now: 10)
        for _ in 0..<18 { XCTAssertTrue(state.fire(now: 11)) }
        XCTAssertFalse(state.fire(now: 11))
        XCTAssertFalse(state.registerHit(targetID: -1, now: 11))
        XCTAssertEqual(state.hitCount, 0)
        state.reload(now: 12)
        XCTAssertEqual(state.ammo, 18)
        state.pause(now: 20)
        state.tick(now: 1000)
        XCTAssertEqual(state.remainingTime, 25)
        XCTAssertFalse(state.fire(now: 1000))
        state.resume(now: 1000)
        state.tick(now: 1024.1)
        XCTAssertEqual(state.remainingTime, 1)
        XCTAssertFalse(state.fire(now: 1025))
        XCTAssertEqual(state.phase, .result)
        state.continueFromResult(now: 1030)
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.remainingTime, 35)
        XCTAssertEqual(state.ammo, 18)
    }

    @MainActor func testSoundVariantsMuteVolumeAndAcceptedShots() throws {
        let storage = try defaults()
        let sound = ShotSound(defaults: storage)
        defer { sound.stop() }
        XCTAssertTrue(sound.loadFailures.isEmpty, "Every shipped effect must be present and decodable")
        storage.set(0.4, forKey: "shotSoundVolume")
        for style in ShotStyle.allCases {
            storage.set(style.rawValue, forKey: "shotSoundStyle")
            var previous: Int?
            var discovered: Set<Int> = []
            for _ in 0..<30 {
                let oldPlayer = sound.player
                sound.play()
                let variant = try XCTUnwrap(sound.lastVariants[style])
                XCTAssertNotEqual(variant, previous)
                discovered.insert(variant)
                if let oldPlayer { XCTAssertFalse(oldPlayer === sound.player) }
                XCTAssertLessThanOrEqual(sound.activeVoiceCount, 2)
                let player = try XCTUnwrap(sound.player)
                XCTAssertTrue(player.isPlaying)
                XCTAssertGreaterThan(player.duration, 0.08)
                XCTAssertEqual(player.volume, 0.096, accuracy: 0.001)
                previous = variant
            }
            XCTAssertEqual(discovered, [0, 1, 2])
        }
        sound.stop()
        for material in HitMaterial.allCases {
            var previous: Int?
            for _ in 0..<30 {
                sound.playHit(material)
                let variant = try XCTUnwrap(sound.lastHitVariants[material])
                XCTAssertNotEqual(variant, previous)
                previous = variant
                XCTAssertTrue(try XCTUnwrap(sound.hitPlayer).isPlaying)
                XCTAssertEqual(try XCTUnwrap(sound.hitPlayer).volume, 0.08, accuracy: 0.001)
                XCTAssertLessThanOrEqual(sound.activeVoiceCount, 2)
            }
        }
        sound.playMilestone()
        XCTAssertTrue(try XCTUnwrap(sound.milestonePlayer).isPlaying)
        sound.playResolution(final: false)
        XCTAssertTrue(try XCTUnwrap(sound.resolutionPlayer).isPlaying)
        sound.playResolution(final: true)
        XCTAssertEqual(try XCTUnwrap(sound.resolutionPlayer).duration, 0.8, accuracy: 0.001)
        for _ in 0..<40 {
            sound.play(); sound.playHit(.rubber); sound.playMilestone()
            XCTAssertLessThanOrEqual(sound.activeVoiceCount, 6)
        }
        storage.set(false, forKey: "shotSoundEnabled")
        sound.stop()
        sound.play(); sound.playHit(.paper); sound.playMilestone(); sound.playResolution(final: false)
        XCTAssertFalse(sound.player?.isPlaying ?? false)
        XCTAssertFalse(sound.hitPlayer?.isPlaying ?? false)
        XCTAssertFalse(sound.resolutionPlayer?.isPlaying ?? false)
        XCTAssertEqual(sound.activeVoiceCount, 0)
        storage.set(true, forKey: "shotSoundEnabled")
        storage.set(0.0, forKey: "shotSoundVolume")
        sound.play(); sound.playHit(.cloth)
        XCTAssertFalse(sound.player?.isPlaying ?? false)
        XCTAssertFalse(sound.hitPlayer?.isPlaying ?? false)
        storage.set(0.3, forKey: "shotSoundVolume")
        let state = GameState(progress: ProgressStore(defaults: storage))
        let world = GameWorld(state: state, sound: sound)
        defer { world.stop() }
        world.shoot()
        XCTAssertFalse(sound.player?.isPlaying ?? false)
        state.start()
        for _ in 0..<18 { world.shoot() }
        XCTAssertEqual(state.ammo, 0)
        sound.stop()
        world.shoot()
        XCTAssertFalse(sound.player?.isPlaying ?? false, "Empty actions must stay silent")
        let previousVariant = sound.lastVariants[.soft]
        world.reload()
        world.shoot()
        XCTAssertEqual(state.ammo, 17)
        XCTAssertNotEqual(sound.lastVariants[.soft], previousVariant, "An accepted shot must trigger a fresh sound; the short clip may finish during a simulator ray query")
    }

    @MainActor func testSafeReplayLayoutsAndCorruptSaveBounds() throws {
        var rng = SeededRandom(seed: 17)
        for stage in Stage.all {
            var layouts: [[SIMD3<Float>]] = []
            for variant in 0..<3 {
                let layout = stage.layout(variant: variant, using: &rng)
                layouts.append(layout.targets)
                XCTAssertEqual(layout.targets.count, stage.targets.count)
                for point in layout.targets {
                    XCTAssertLessThanOrEqual(abs(point.x), 6.5)
                    XCTAssertGreaterThanOrEqual(point.z, -12.5)
                    XCTAssertLessThanOrEqual(point.z, 4)
                    XCTAssertFalse(layout.obstacles.contains {
                        abs(point.x - $0.position.x) < $0.size.x / 2 + 0.5 &&
                        abs(point.z - $0.position.z) < $0.size.z / 2 + 0.5
                    })
                }
            }
            XCTAssertNotEqual(layouts[0], layouts[1])
        }
        var previous: Int?
        for _ in 0..<1000 {
            let next = ShotSound.nextVariant(after: previous, using: &rng)
            XCTAssertTrue((0..<3).contains(next))
            XCTAssertNotEqual(next, previous)
            previous = next
        }
        let storage = try defaults()
        storage.set([-1, 30], forKey: "progress.cleared")
        storage.set(500, forKey: "progress.current")
        storage.set(["garbage", "12:8"], forKey: "progress.endings")
        let restored = ProgressStore(defaults: storage)
        XCTAssertEqual(restored.currentStage, 0)
        XCTAssertTrue(restored.cleared.isEmpty)
        XCTAssertTrue(restored.endings.isEmpty)
    }

    @MainActor func testNonARCameraMovementAndAimBounds() async throws {
        let storage = try defaults()
        let state = GameState(progress: ProgressStore(defaults: storage))
        state.start()
        let sound = ShotSound(defaults: storage)
        let world = GameWorld(state: state, sound: sound)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = try XCTUnwrap(scene.windows.first)
        world.view.frame = host.bounds
        host.addSubview(world.view)
        world.start()
        defer { world.stop(); world.view.removeFromSuperview() }
        XCTAssertEqual(world.view.cameraMode, .nonAR)
        XCTAssertEqual(world.targets.count, 4)
        XCTAssertTrue(world.targets.allSatisfy { $0.collision != nil })
        try await Task.sleep(for: .milliseconds(500))
        for direction: SIMD2<Float> in [[0, 1], [1, 0], [0, -1], [-1, 0]] {
            let before = world.camera.position
            world.move = direction
            try await Task.sleep(for: .milliseconds(250))
            world.move = .zero
            XCTAssertGreaterThan(simd_distance(before, world.camera.position), 0.1)
        }
        world.look(delta: CGSize(width: 0, height: 10000))
        XCTAssertGreaterThan(world.camera.orientation.act(SIMD3<Float>(0, 0, -1)).y, -1)
        world.stop()
        XCTAssertTrue(world.view.scene.anchors.isEmpty)
    }

    @MainActor func testRenderedTenEnemiesResolutionAndFinalResult() async throws {
        let storage = try defaults()
        storage.set(false, forKey: "shotSoundEnabled")
        let state = GameState(progress: ProgressStore(defaults: storage))
        let sound = ShotSound(defaults: storage)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = try XCTUnwrap(scene.windows.first)
        state.start()
        for index in Stage.all.indices {
            let world = GameWorld(state: state, sound: sound)
            world.view.frame = host.bounds
            host.addSubview(world.view)
            world.start()
            defer { world.stop(); world.view.removeFromSuperview() }
            try await Task.sleep(for: .milliseconds(500))
            try await aim(world, at: world.targets[0])
            let previewPosition = world.camera.position
            await captureWorld("Stage\(index + 1)-Before", world)
            for id in world.targets.indices {
                let target = world.targets[id]
                for _ in 0..<state.stage.kind.hitsToResolve {
                    try await aim(world, at: target)
                    if state.ammo == 0 { world.reload() }
                    let before = state.hitCount
                    world.shoot()
                    XCTAssertEqual(state.hitCount, before + 1, "Stage \(index + 1) rendered ray must hit")
                }
                XCTAssertNil(target.collision, "Solved enemies must not block the remaining ones")
            }
            XCTAssertTrue(state.isCleared)
            XCTAssertEqual(state.phase, .resolution)
            world.camera.look(at: world.targets[0].position, from: previewPosition, relativeTo: nil)
            try await Task.sleep(for: .milliseconds(350))
            await captureWorld("Stage\(index + 1)-Solved", world)
            state.tick(now: ProcessInfo.processInfo.systemUptime + 3)
            XCTAssertEqual(state.phase, .result)
            if state.isFinalStage {
                let renderer = ImageRenderer(content: ResultView(state: state, onContinue: {}, onTitle: {})
                    .frame(width: 390, height: 844).preferredColorScheme(.light))
                let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
                attachment.name = "FinalClear"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            state.continueFromResult()
        }
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.phase, .game)
        XCTAssertEqual(ProgressStore(defaults: storage).cleared.count, 10)
    }

    @MainActor private func aim(_ world: GameWorld, at target: ModelEntity) async throws {
        let targetPosition = target.position(relativeTo: nil)
        let offsets: [SIMD3<Float>] = [[0, 0, 2.8], [-2, 0, 2.8], [2, 0, 2.8], [2.8, 0, 0], [-2.8, 0, 0], [0, 0, -2.8]]
        let vantage = offsets.map { offset -> SIMD3<Float> in
            let point = targetPosition + offset
            return [point.x, 1.6, point.z]
        }.first { point in
            guard world.canStand(at: point) else { return false }
            return world.view.scene.raycast(origin: point, direction: simd_normalize(targetPosition - point),
                                            length: 40, query: .nearest).first?.entity === target
        }
        let position = try XCTUnwrap(vantage, "Every enemy must be visible from an in-bounds position")
        world.camera.look(at: targetPosition, from: position, relativeTo: nil)
        try await Task.sleep(for: .milliseconds(80))
    }

    @MainActor private func captureWorld(_ name: String, _ world: GameWorld) async {
        let snapshot: UIImage? = await withCheckedContinuation { continuation in
            world.view.snapshot(saveToHDR: false) { continuation.resume(returning: $0) }
        }
        guard let snapshot else { XCTFail("Missing world snapshot: \(name)"); return }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}
