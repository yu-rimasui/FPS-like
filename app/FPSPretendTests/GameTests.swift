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

    @MainActor private func hit(_ state: GameState, target: Int, now: Double) {
        if state.ammo == 0 { state.reload(now: now) }
        XCTAssertTrue(state.fire(now: now))
        XCTAssertTrue(state.registerHit(targetID: target, now: now))
    }

    @MainActor private func clear(_ state: GameState, now: Double) {
        for target in state.targetHits.indices {
            for _ in state.targetHits[target]..<state.stage.hitsRequired(for: target) { hit(state, target: target, now: now) }
        }
    }

    @MainActor func testFiveStageSpecificationAndRoundedHitLimits() {
        XCTAssertEqual(Stage.all.count, 5)
        XCTAssertEqual(EnemyKind.allCases.count, 5)
        XCTAssertEqual(Stage.all.map(\.requiredTargets), [3, 4, 4, 4, 4])
        XCTAssertEqual(Stage.all.map(\.requiredHits), [15, 20, 20, 20, 20])
        let motions: [[EnemyMotion]] = [
            [.lying, .sliding, .walking], [.walking, .walking, .running, .running],
            [.dancing, .dancing, .dancing, .dancing], [.laughing, .laughing, .laughing, .laughing],
            [.skipping, .skipping, .flying, .flying]
        ]
        let obstacles: [Stage.Obstacle.Kind] = [.wall, .windmill, .ball, .maze, .meteor]
        for (id, stage) in Stage.all.enumerated() {
            XCTAssertEqual(stage.timeLimit, 60)
            XCTAssertEqual(stage.motions, motions[id])
            XCTAssertEqual(stage.motions.count, stage.targets.count)
            XCTAssertTrue(stage.obstacles.allSatisfy { $0.kind == obstacles[id] })
            for target in stage.targets.indices {
                let expected = Int(ceil(Double(stage.hitBudget) / Double(stage.targets.count) / 5)) * 5
                XCTAssertEqual(stage.hitsRequired(for: target), expected)
            }
        }
    }

    @MainActor func testProgressAndCollectionSurviveInterruptionAndRetry() throws {
        let storage = try defaults()
        let progress = ProgressStore(defaults: storage)
        let state = GameState(progress: progress)
        XCTAssertFalse(state.start(stageIndex: 1, now: 10))
        XCTAssertTrue(state.start(stageIndex: 0, now: 10))
        XCTAssertEqual(state.variant, 0)
        for _ in 0..<state.stage.hitsRequired(for: 0) { hit(state, target: 0, now: 11) }
        XCTAssertFalse(state.isCleared)
        XCTAssertTrue(state.fire(now: 12))
        XCTAssertFalse(state.registerHit(targetID: 0, now: 12))
        XCTAssertEqual(state.hitCount, 5)
        state.returnToTitle()
        let restored = ProgressStore(defaults: storage)
        XCTAssertTrue(restored.seen.contains(0))
        XCTAssertTrue(restored.endings.contains("0:0"))
        XCTAssertEqual(restored.unlockedStage, 0)
        state.start(stageIndex: 0, now: 100)
        XCTAssertEqual(state.variant, 1)
        state.tick(now: 160)
        XCTAssertFalse(state.isCleared)
        state.continueFromResult(now: 200)
        XCTAssertEqual(state.variant, 2)
        XCTAssertTrue(progress.endings.contains("0:0"))
        clear(state, now: 201)
        XCTAssertEqual(state.phase, .resolution)
        XCTAssertEqual(ProgressStore(defaults: storage).unlockedStage, 1)
        XCTAssertTrue(ProgressStore(defaults: storage).endings.contains("0:2"))
        state.finishResolution()
        state.continueFromResult(now: 205)
        XCTAssertEqual(state.stageIndex, 1)
        XCTAssertEqual(state.remainingTime, 60)
        XCTAssertEqual(state.hitCount, 0)
        XCTAssertEqual(state.resolvedCount, 0)
        XCTAssertEqual(ProgressStore(defaults: storage).currentStage, 1)
    }

    @MainActor func testAllFiveStagesResolveThenRestartWithoutLosingCollection() throws {
        let storage = try defaults()
        let progress = ProgressStore(defaults: storage)
        let state = GameState(progress: progress)
        state.start(stageIndex: 0, now: 10)
        for (index, stage) in Stage.all.enumerated() {
            let now = Double(index) * 200 + 10
            XCTAssertEqual(state.stageIndex, index)
            for target in state.targetHits.indices {
                for count in 0..<stage.hitsRequired(for: target) {
                    if target == state.targetHits.count - 1 && count == stage.hitsRequired(for: target) - 1 {
                        XCTAssertFalse(state.isCleared, "Every doll must disappear before clearing")
                    }
                    hit(state, target: target, now: now)
                    let hitCount = state.hitCount
                    XCTAssertFalse(state.registerHit(targetID: target, now: now))
                    XCTAssertEqual(state.hitCount, hitCount)
                }
            }
            XCTAssertEqual(state.phase, .resolution)
            XCTAssertTrue(state.isCleared)
            XCTAssertEqual(state.resolvedCount, stage.targets.count)
            XCTAssertEqual(state.hitCount, stage.requiredHits)
            XCTAssertFalse(state.fire(now: now))
            state.tick(now: now + 3)
            XCTAssertEqual(state.phase, .result)
            XCTAssertTrue(progress.cleared.contains(index))
            XCTAssertTrue(progress.endings.contains("\(index):0"))
            state.continueFromResult(now: now + 200)
            XCTAssertEqual(state.hitCount, 0)
            XCTAssertEqual(state.remainingTime, 60)
        }
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.phase, .game)
        XCTAssertEqual(state.score, 0)
        let reloaded = ProgressStore(defaults: storage)
        XCTAssertEqual(reloaded.cleared.count, 5)
        XCTAssertEqual(reloaded.seen.count, 5)
        XCTAssertEqual(reloaded.endings.count, 5)
        XCTAssertEqual(reloaded.unlockedStage, 4)
        state.returnToTitle()
        XCTAssertTrue(state.start(stageIndex: 4))
        XCTAssertFalse(state.start(stageIndex: 5))
    }

    @MainActor func testCompletionCommentsKeepAlternateEndings() throws {
        let storage = try defaults()
        storage.set(Array(Stage.all.indices), forKey: "progress.cleared")
        let state = GameState(progress: ProgressStore(defaults: storage))
        for index in Stage.all.indices {
            var endings: Set<String> = []
            for _ in 0..<3 {
                state.start(stageIndex: index, now: 0)
                clear(state, now: 1)
                XCTAssertEqual(state.message, state.ending)
                XCTAssertTrue(state.isCleared)
                endings.insert(state.ending)
            }
            XCTAssertEqual(endings.count, 3)
        }
    }

    @MainActor func testDeadlineAndLastHitCannotCompleteTwice() throws {
        let state = GameState(progress: ProgressStore(defaults: try defaults()))
        for beforeDeadline in [true, false] {
            state.start(stageIndex: 0, now: 100)
            for target in state.targetHits.indices {
                let count = state.stage.hitsRequired(for: target) - (target == 2 ? 1 : 0)
                for _ in 0..<count { hit(state, target: target, now: 101) }
            }
            XCTAssertTrue(state.fire(now: 159.9))
            XCTAssertEqual(state.registerHit(targetID: 2, now: beforeDeadline ? 159.99 : 160), beforeDeadline)
            XCTAssertEqual(state.isCleared, beforeDeadline)
            XCTAssertEqual(state.phase, beforeDeadline ? .resolution : .result)
            let hits = state.hitCount
            state.tick(now: 160)
            XCTAssertFalse(state.registerHit(targetID: 2, now: 160))
            XCTAssertEqual(state.hitCount, hits)
            state.tick(now: 170)
            XCTAssertEqual(state.phase, .result)
            state.continueFromResult(now: 200)
            XCTAssertEqual(state.stageIndex, beforeDeadline ? 1 : 0)
            XCTAssertEqual(state.remainingTime, 60)
            XCTAssertEqual(state.hitCount, 0)
            state.tick(now: 201)
            XCTAssertEqual(state.phase, .game, "The previous deadline must not finish the next stage")
        }
    }

    @MainActor func testOriginalDollDimensionsAndDistinctMotions() {
        let original: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([0.6, 0.32, 0.7], [0, 0, 0]), ([0.4, 0.36, 0.4], [0, 0, -0.57]),
            ([0.22, 0.24, 0.65], [-0.44, -0.02, 0]), ([0.22, 0.24, 0.65], [0.44, -0.02, 0]),
            ([0.23, 0.27, 0.6], [-0.17, -0.02, 0.62]), ([0.23, 0.27, 0.6], [0.17, -0.02, 0.62])
        ]
        let doll = EnemyVisual(motion: .lying, position: [0, 0.28, 0], color: EnemyVisual.colors[0], requiredHits: 5)
        let figure = doll.entity.children[0]
        let parts = models(figure).filter { $0.model?.materials.first is SimpleMaterial }
        XCTAssertEqual(parts.count, 6)
        for (part, expected) in zip(parts, original) {
            XCTAssertLessThan(simd_distance(part.model!.mesh.bounds.extents, expected.0), 0.0001)
            XCTAssertLessThan(simd_distance(part.position(relativeTo: figure), expected.1), 0.0001)
        }
        let still = transforms(doll.entity)
        doll.update(time: 2, reducedMotion: false)
        XCTAssertEqual(transforms(doll.entity), still)
        var signatures: [[Transform]] = []
        for motion in EnemyMotion.allCases {
            let enemy = EnemyVisual(motion: motion, position: [0, motion.height, 0], color: EnemyVisual.colors[0], requiredHits: 5)
            enemy.update(time: 0.4, reducedMotion: false)
            let first = transforms(enemy.entity)
            enemy.update(time: 1.2, reducedMotion: false)
            if motion != .lying && motion != .sliding { XCTAssertNotEqual(transforms(enemy.entity), first) }
            if motion == .flying { XCTAssertGreaterThan(enemy.entity.visualBounds(relativeTo: nil).min.y, 0.9) }
            if motion == .skipping { XCTAssertGreaterThan(enemy.entity.position.y, motion.height) }
            signatures.append(transforms(enemy.entity))
            enemy.update(time: 2, reducedMotion: true)
            let quiet = transforms(enemy.entity.children[0])
            enemy.update(time: 3, reducedMotion: true)
            XCTAssertEqual(transforms(enemy.entity.children[0]), quiet)
        }
        XCTAssertNotEqual(signatures[2], signatures[3], "Walking and running must differ in limbs and movement")
    }

    @MainActor func testHitColorRestoresAndRepeatedHitExtendsOnlyThatDoll() {
        for color in EnemyVisual.colors {
            let enemy = EnemyVisual(motion: .lying, position: [0, 0.28, 0], color: color, requiredHits: 5)
            let other = EnemyVisual(motion: .lying, position: [0, 0.28, -3], color: color, requiredHits: 5)
            let part = models(enemy.entity)[0]
            func tint() -> UIColor { (part.model!.materials[0] as! SimpleMaterial).color.tint }
            let original = tint()
            let otherOriginal = (models(other.entity)[0].model!.materials[0] as! SimpleMaterial).color.tint
            enemy.react(hits: 1, time: 10)
            XCTAssertTrue(enemy.isDarkened)
            XCTAssertNotEqual(tint(), original)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
            tint().getRed(&dr, green: &dg, blue: &db, alpha: &da)
            XCTAssertEqual(dr / r, dg / g, accuracy: 0.001)
            XCTAssertEqual(dg / g, db / b, accuracy: 0.001)
            XCTAssertEqual(dr / r, 0.6, accuracy: 0.001)
            enemy.update(time: 10.99, reducedMotion: false)
            XCTAssertTrue(enemy.isDarkened)
            enemy.update(time: 11, reducedMotion: false)
            XCTAssertEqual(tint(), original)
            enemy.react(hits: 2, time: 12)
            enemy.react(hits: 3, time: 12.75)
            enemy.update(time: 13, reducedMotion: true)
            XCTAssertTrue(enemy.isDarkened)
            enemy.update(time: 13.75, reducedMotion: true)
            XCTAssertFalse(enemy.isDarkened)
            XCTAssertEqual(tint(), original)
            other.update(time: 13.75, reducedMotion: false)
            XCTAssertFalse(other.isDarkened)
            XCTAssertEqual((models(other.entity)[0].model!.materials[0] as! SimpleMaterial).color.tint, otherOriginal)
            enemy.react(hits: 4, time: 14)
            enemy.react(hits: 5, time: 14.1)
            XCTAssertFalse(enemy.entity.isEnabled)
            XCTAssertNil(enemy.entity.collision)
        }
    }

    @MainActor private func models(_ entity: Entity) -> [ModelEntity] {
        let own = (entity as? ModelEntity).map { $0.model == nil ? [] : [$0] } ?? []
        return own + entity.children.flatMap { models($0) }
    }

    @MainActor private func transforms(_ entity: Entity) -> [Transform] {
        [entity.transform] + entity.children.flatMap { transforms($0) }
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
        state.pause(now: 20)
        state.tick(now: 1000)
        XCTAssertEqual(state.remainingTime, 50)
        XCTAssertFalse(state.fire(now: 1000))
        state.resume(now: 1000)
        state.tick(now: 1049.1)
        XCTAssertEqual(state.remainingTime, 1)
        XCTAssertFalse(state.fire(now: 1050))
        XCTAssertEqual(state.phase, .result)
        XCTAssertFalse(state.isCleared)
        state.continueFromResult(now: 1090)
        XCTAssertEqual(state.stageIndex, 0)
        XCTAssertEqual(state.remainingTime, 60)
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
            XCTAssertGreaterThanOrEqual(stage.obstacles.count, 2)
            var layouts: [[SIMD3<Float>]] = []
            for variant in 0..<3 {
                let layout = stage.layout(variant: variant, using: &rng)
                XCTAssertFalse(layout.obstacles.contains {
                    abs(stage.playerStart.x - $0.position.x) < $0.size.x / 2 + 0.25 && abs(stage.playerStart.z - $0.position.z) < $0.size.z / 2 + 0.25
                }, "Obstacles must not overlap the player spawn")
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

    @MainActor func testOldTenStageSaveKeepsValidProgressAndVisitCounts() throws {
        let storage = try defaults()
        storage.set(Array(0..<10), forKey: "progress.cleared")
        storage.set(Array(0..<10), forKey: "progress.seen")
        storage.set(Array(repeating: 2, count: 10), forKey: "progress.visits")
        storage.set(9, forKey: "progress.current")
        storage.set(["0:1", "4:2", "9:0"], forKey: "progress.endings")
        let progress = ProgressStore(defaults: storage)
        XCTAssertEqual(progress.cleared, Set(0..<5))
        XCTAssertEqual(progress.seen, Set(0..<5))
        XCTAssertEqual(progress.endings, ["0:1", "4:2"])
        XCTAssertEqual(progress.currentStage, 4)
        XCTAssertEqual(progress.beginVisit(0), 2)
    }

    @MainActor func testStoppedWorldCannotChangeNextStageOrCarryHitColors() throws {
        let storage = try defaults()
        let state = GameState(progress: ProgressStore(defaults: storage))
        state.start(now: 0)
        let sound = ShotSound(defaults: storage)
        let old = GameWorld(state: state, sound: sound)
        old.enemies[0].react(hits: 1, time: 0)
        XCTAssertTrue(old.enemies[0].isDarkened)
        clear(state, now: 1)
        state.continueFromResult(now: 2)
        old.stop()
        let next = GameWorld(state: state, sound: sound)
        defer { next.stop() }
        let position = old.targets[1].position
        old.updateScene(time: 10, reducedMotion: false)
        old.shoot()
        XCTAssertEqual(old.targets[1].position, position)
        XCTAssertEqual(state.hitCount, 0)
        XCTAssertEqual(state.shotCount, 0)
        XCTAssertEqual(state.remainingTime, 60)
        XCTAssertTrue(next.enemies.allSatisfy { !$0.isDarkened && $0.entity.isEnabled })
        XCTAssertTrue(old.view.scene.anchors.isEmpty)
    }

    @MainActor func testObstaclesBlockMovementAndFollowTheirMotion() throws {
        let storage = try defaults()
        storage.set(Array(Stage.all.indices), forKey: "progress.cleared")
        let state = GameState(progress: ProgressStore(defaults: storage))
        let sound = ShotSound(defaults: storage)
        for id in Stage.all.indices {
            state.start(stageIndex: id)
            let world = GameWorld(state: state, sound: sound)
            defer { world.stop() }
            world.updateScene(time: 0, reducedMotion: false)
            XCTAssertTrue(world.canStand(at: [0, 1.6, 3]))
            let definition = state.stage.obstacles[0]
            let point = SIMD3<Float>(definition.position.x, 1.6, definition.position.z)
            XCTAssertEqual(world.canStand(at: point), definition.kind == .meteor)
            let animated = world.view.scene.anchors[0].children.first { $0.name == "obstacle.\(definition.kind)" }
            if definition.kind == .wall || definition.kind == .maze { continue }
            let entity = try XCTUnwrap(animated)
            let before = entity.transform
            world.updateScene(time: 1, reducedMotion: false)
            XCTAssertNotEqual(entity.transform, before)
            if definition.kind == .ball {
                XCTAssertTrue(world.canStand(at: [definition.position.x - 0.8, 1.6, definition.position.z]))
                XCTAssertFalse(world.canStand(at: [entity.position.x, 1.6, entity.position.z]))
            }
            if definition.kind == .meteor {
                world.updateScene(time: 3.9, reducedMotion: false)
                XCTAssertFalse(world.canStand(at: point))
            }
        }
    }

    @MainActor func testRoamingCoversStageWithoutCrossingWallsOrStopping() throws {
        let storage = try defaults()
        storage.set(Array(Stage.all.indices), forKey: "progress.cleared")
        storage.set(false, forKey: "shotSoundEnabled")
        let state = GameState(progress: ProgressStore(defaults: storage))
        let sound = ShotSound(defaults: storage)
        for stageID in Stage.all.indices {
            state.start(stageIndex: stageID)
            let world = GameWorld(state: state, sound: sound)
            defer { world.stop() }
            var low = world.targets.map { SIMD2<Float>($0.position.x, $0.position.z) }
            var high = low
            var travelled = Array(repeating: Float.zero, count: world.targets.count)
            var recent = travelled
            for step in 1...1200 {
                let previous = world.targets.map { SIMD2<Float>($0.position.x, $0.position.z) }
                world.updateScene(time: Float(step) / 20, reducedMotion: false)
                for id in world.targets.indices {
                    let target = world.targets[id]
                    let position = SIMD2<Float>(target.position.x, target.position.z)
                    let distance = simd_distance(position, previous[id])
                    XCTAssertTrue(world.canRoam(from: previous[id], to: position), "Stage \(stageID + 1), doll \(id) crossed a wall")
                    XCTAssertLessThanOrEqual(distance, state.stage.motions[id].speed / 20 + 0.001, "No teleports")
                    low[id] = simd_min(low[id], position)
                    high[id] = simd_max(high[id], position)
                    travelled[id] += distance
                    recent[id] += distance
                    if step % 40 == 0 && state.stage.motions[id].speed > 0 {
                        XCTAssertGreaterThan(recent[id], state.stage.motions[id].speed, "A doll must keep moving through corners and dead ends")
                        recent[id] = 0
                    }
                    if stageID == 3 {
                        let bounds = target.visualBounds(relativeTo: nil)
                        for wall in state.stage.obstacles {
                            let minimum = wall.position - wall.size / 2
                            let maximum = wall.position + wall.size / 2
                            XCTAssertFalse(bounds.min.x < maximum.x && bounds.max.x > minimum.x && bounds.min.z < maximum.z && bounds.max.z > minimum.z,
                                           "Animated body parts must also stay clear of maze walls")
                        }
                    }
                }
            }
            for id in world.targets.indices {
                let span = high[id] - low[id]
                if state.stage.motions[id].speed == 0 {
                    XCTAssertEqual(travelled[id], 0)
                    continue
                }
                print("Roaming stage \(stageID + 1), doll \(id): span \(span), distance \(travelled[id])m")
                XCTAssertGreaterThanOrEqual(span.x, 8 - 0.001)
                XCTAssertGreaterThanOrEqual(span.y, 10 - 0.001)
                XCTAssertGreaterThan(travelled[id], state.stage.motions[id].speed * 49)
            }
        }
    }

    @MainActor func testReferenceMazeJointsPassagesAndDeadEndRoutes() async throws {
        let storage = try defaults()
        storage.set(Array(Stage.all.indices), forKey: "progress.cleared")
        storage.set(false, forKey: "shotSoundEnabled")
        let state = GameState(progress: ProgressStore(defaults: storage))
        state.start(stageIndex: 3)
        let world = GameWorld(state: state, sound: ShotSound(defaults: storage))
        defer { world.stop(); world.view.removeFromSuperview() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = try XCTUnwrap(scene.windows.first)
        world.view.frame = host.bounds
        host.addSubview(world.view)
        world.start()
        try await Task.sleep(for: .milliseconds(500))
        world.setActive(false)
        XCTAssertEqual(world.camera.position, [1.7, 1.6, 3.8])
        XCTAssertEqual(state.stage.obstacles.count, 17)
        func point(_ pixel: SIMD2<Float>) -> SIMD2<Float> {
            [(pixel.x - 18) / 478 * 16 - 8, (pixel.y - 14) / 478 * 20 - 14]
        }
        let joints: [SIMD2<Float>] = [[18, 14], [496, 14], [496, 492], [18, 492], [108, 262], [350, 104],
                                    [405, 254], [310, 254], [204, 200], [244, 308], [244, 402], [108, 402], [380, 402], [380, 492]]
        for joint in joints {
            let p = point(joint)
            for offset: Float in [-0.04, 0, 0.04] {
                let sample = SIMD2<Float>(p.x + offset, p.y + offset)
                XCTAssertFalse(world.canStand(at: [sample.x, 1.6, sample.y]), "Player must not cross a seam at \(joint)")
                XCTAssertFalse(world.canRoam(from: sample, to: sample), "Dolls must not cross a seam")
                let hit = try XCTUnwrap(world.view.scene.raycast(origin: [sample.x, 4, sample.y], direction: [0, -1, 0], length: 6, query: .nearest).first, "Missing wall collider at \(joint), offset \(offset)")
                XCTAssertGreaterThanOrEqual(hit.position.y, 1.79, "A visible wall joint must have a collider")
            }
        }
        for passage: SIMD2<Float> in [[268, 104], [405, 308], [310, 402], [108, 348], [156, 200], [450, 200], [65, 200]] {
            let p = point(passage)
            XCTAssertTrue(world.canStand(at: [p.x, 1.6, p.y]), "Reference passage must stay open at \(passage)")
            XCTAssertTrue(world.canRoam(from: p, to: p), "Passages must fit a whole doll")
        }
        var rng = SeededRandom(seed: 42)
        for pixel: SIMD2<Float> in [[360, 210], [450, 55], [156, 355], [450, 440]] {
            var previous = point(pixel)
            let route = GameWorld.roamingRoute(from: previous, using: &rng) { world.canRoam(from: $0, to: $1) }
            XCTAssertGreaterThan(route.count, 20, "Dead ends must have a continuous exit route")
            for next in route.reversed() {
                XCTAssertTrue(world.canRoam(from: previous, to: next))
                XCTAssertLessThanOrEqual(simd_distance(previous, next), 0.8)
                previous = next
            }
        }
        let walls = world.view.scene.anchors[0].children.compactMap { $0 as? ModelEntity }.filter { $0.model != nil && $0.visualBounds(relativeTo: nil).max.y > 0.1 }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 540, height: 540))
        let map = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 540, height: 540))
            UIColor.black.setFill()
            for wall in walls {
                let bounds = wall.visualBounds(relativeTo: nil)
                let rect = CGRect(x: CGFloat((bounds.min.x + 8) / 16) * 478 + 30,
                                  y: CGFloat((bounds.min.z + 14) / 20) * 478 + 30,
                                  width: CGFloat(bounds.extents.x / 16) * 478,
                                  height: CGFloat(bounds.extents.z / 20) * 478)
                context.fill(rect)
            }
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: CGFloat((world.camera.position.x + 8) / 16) * 478 + 21,
                                y: CGFloat((world.camera.position.z + 14) / 20) * 478 + 21, width: 18, height: 18))
        }
        let attachment = XCTAttachment(image: map)
        attachment.name = "ReferenceMazeTopDown"
        attachment.lifetime = .keepAlways
        add(attachment)
        await captureWorld("MazeStartingView", world)
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
        XCTAssertEqual(world.targets.count, 3)
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

    @MainActor func testRenderedFiveStagesDisappearanceAndFinalResult() async throws {
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
            var longestShot = 0.0
            for id in world.targets.indices {
                storage.set(id == 0, forKey: "shotSoundEnabled")
                storage.set(0.2, forKey: "shotSoundVolume")
                sound.stop()
                let target = world.targets[id]
                try await aim(world, at: target)
                let required = state.stage.hitsRequired(for: id)
                for hitIndex in 1...required {
                    try await aim(world, at: target)
                    if state.ammo == 0 { world.reload() }
                    let before = state.hitCount
                    let previousSound = sound.lastHitVariants[state.stage.kind.material]
                    let shotStarted = ProcessInfo.processInfo.systemUptime
                    world.shoot()
                    longestShot = max(longestShot, ProcessInfo.processInfo.systemUptime - shotStarted)
                    if id == 0 {
                        XCTAssertNotEqual(sound.lastHitVariants[state.stage.kind.material], previousSound)
                        if hitIndex == required { XCTAssertNotNil(sound.resolutionPlayer) }
                        else if hitIndex * 4 / required > (hitIndex - 1) * 4 / required { XCTAssertNotNil(sound.milestonePlayer) }
                    } else { XCTAssertEqual(sound.activeVoiceCount, 0) }
                    XCTAssertEqual(state.hitCount, before + 1, "Stage \(index + 1) rendered ray must hit")
                    XCTAssertFalse(state.registerHit(targetID: id), "Ray callbacks cannot double count")
                    try await Task.sleep(for: .milliseconds(16))
                    if id == 0 && (hitIndex == (required + 1) / 2 || hitIndex == required - 1) {
                        await captureWorld("Stage\(index + 1)-Progress\(hitIndex)", world)
                    }
                }
                XCTAssertNil(target.collision, "Solved enemies must not block the remaining ones")
                XCTAssertFalse(target.isEnabled, "Solved dolls must disappear")
            }
            print("Stage \(index + 1): \(state.hitCount) accepted rays; longest shoot call \(String(format: "%.3f", longestShot))s")
            XCTAssertTrue(state.isCleared)
            XCTAssertEqual(state.phase, .resolution)
            world.camera.look(at: world.targets[0].position, from: previewPosition, relativeTo: nil)
            try await Task.sleep(for: .milliseconds(350))
            await captureWorld("Stage\(index + 1)-Solved", world)
            state.tick(now: ProcessInfo.processInfo.systemUptime + 3)
            XCTAssertEqual(state.phase, .result)
            if state.isFinalStage {
                let renderer = ImageRenderer(content: ResultView(state: state, onContinue: {}, onRetry: {}, onTitle: {})
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
        XCTAssertEqual(ProgressStore(defaults: storage).cleared.count, 5)
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
        world.camera.position = position
        world.camera.look(at: targetPosition, from: position, relativeTo: nil)
        try await Task.sleep(for: .milliseconds(16))
        world.camera.look(at: target.position(relativeTo: nil), from: position, relativeTo: nil)
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
