import XCTest
import RealityKit
@testable import FPSPretend

final class GameTests: XCTestCase {
    @MainActor func testSessionBoundariesAndReplay() {
        let state = GameState()
        XCTAssertEqual(state.accuracy, 0)
        XCTAssertFalse(state.fire(now: 0))
        state.start(now: 10)
        XCTAssertTrue(state.fire(now: 11))
        state.registerHit(now: 11)
        XCTAssertTrue(state.fire(now: 12))
        state.registerHit(now: 12)
        XCTAssertEqual(state.score, 200)
        XCTAssertEqual(state.currentCombo, 2)
        state.tick(now: 14)
        XCTAssertEqual(state.currentCombo, 0)
        XCTAssertFalse(state.hitFeedback)
        for _ in 0..<16 { XCTAssertTrue(state.fire(now: 15)) }
        XCTAssertFalse(state.fire(now: 15))
        XCTAssertEqual(state.shotCount, 18)
        XCTAssertEqual(state.accuracy, 11)
        state.reload(now: 16)
        XCTAssertEqual(state.ammo, 18)
        state.tick(now: 69.1)
        XCTAssertEqual(state.remainingTime, 1)
        XCTAssertFalse(state.fire(now: 70))
        XCTAssertEqual(state.phase, .result)
        XCTAssertEqual(state.maxCombo, 2)
        state.reload(now: 71)
        state.registerHit(now: 71)
        XCTAssertEqual(state.score, 200)
        state.start(now: 100)
        XCTAssertEqual(state.phase, .game)
        XCTAssertEqual(state.score, 0)
        XCTAssertEqual(state.ammo, 18)
        XCTAssertEqual(state.remainingTime, 60)
        XCTAssertEqual(state.maxCombo, 0)
        XCTAssertEqual(state.hitCount, 0)
        XCTAssertEqual(state.shotCount, 0)
    }

    @MainActor func testWorldHasNonARCameraAndCompoundPhysics() {
        let state = GameState()
        let world = GameWorld(state: state)
        XCTAssertEqual(world.view.cameraMode, .nonAR)
        XCTAssertEqual(world.targets.count, 4)
        XCTAssertTrue(world.targets.allSatisfy { $0.physicsBody?.mode == .dynamic && $0.collision?.shapes.count == 6 })
        state.start()
        world.look(delta: CGSize(width: 0, height: 10000))
        let forward = world.camera.orientation.act(SIMD3<Float>(0, 0, -1))
        XCTAssertGreaterThan(forward.y, -1)
        XCTAssertLessThan(forward.y, -0.8)
        world.stop()
        XCTAssertTrue(world.view.scene.anchors.isEmpty)
    }

    @MainActor func testRenderedHitImpulseAndMovement() async throws {
        let state = GameState()
        let world = GameWorld(state: state)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let host = try XCTUnwrap(scene.windows.first)
        world.view.frame = host.bounds
        host.addSubview(world.view)
        world.start()
        defer { world.stop(); world.view.removeFromSuperview() }
        try await Task.sleep(for: .seconds(1))
        let target = world.targets[0]
        let before = target.position(relativeTo: nil)
        world.shoot()
        XCTAssertEqual(state.score, 100, "Center-screen ray must hit the prone dummy")
        try await Task.sleep(for: .seconds(0.5))
        XCTAssertGreaterThan(simd_distance(before, target.position(relativeTo: nil)), 0.01, "Physics impulse must move the whole dummy")
        let start = world.camera.position
        world.move = [0, 1]
        try await Task.sleep(for: .seconds(0.3))
        world.move = .zero
        XCTAssertLessThan(world.camera.position.z, start.z - 0.1)
        let forward = world.camera.position
        world.move = [1, 0]
        try await Task.sleep(for: .seconds(0.3))
        world.move = .zero
        XCTAssertGreaterThan(world.camera.position.x, forward.x + 0.1)
        let right = world.camera.position
        world.move = [0, -1]
        try await Task.sleep(for: .seconds(0.3))
        world.move = .zero
        XCTAssertGreaterThan(world.camera.position.z, right.z + 0.1)
        let back = world.camera.position
        world.move = [-1, 0]
        try await Task.sleep(for: .seconds(0.3))
        world.move = .zero
        XCTAssertLessThan(world.camera.position.x, back.x - 0.1)
    }
}
