import RealityKit
import UIKit
import simd

@MainActor
final class GameWorld: NSObject {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    let camera = PerspectiveCamera()
    private let root = AnchorEntity(world: .zero)
    private let state: GameState
    private let sound: ShotSound
    private var displayLink: CADisplayLink?
    private var lastFrame = 0.0
    private var yaw: Float = 0
    private var pitch: Float = -0.26
    var move = SIMD2<Float>.zero
    private var obstacles: [(center: SIMD3<Float>, size: SIMD3<Float>)] = []
    private(set) var targets: [ModelEntity] = []
    private var enemies: [EnemyVisual] = []
    private var elapsed: Float = 0
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    init(state: GameState, sound: ShotSound) {
        self.state = state
        self.sound = sound
        super.init()
        view.environment.background = .color(UIColor(red: 0.9, green: 0.93, blue: 0.87, alpha: 1))
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        view.scene.addAnchor(root)
        camera.camera.fieldOfViewInDegrees = 65
        camera.position = [0, 1.6, 3]
        root.addChild(camera)
        orientCamera()
        let light = DirectionalLight()
        light.light.intensity = 2200
        light.look(at: [0, 0, -2], from: [3, 8, 5], relativeTo: nil)
        root.addChild(light)
        let paper = UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1)
        let sage = UIColor(red: 0.72, green: 0.79, blue: 0.61, alpha: 1)
        let coral = UIColor(red: 0.93, green: 0.67, blue: 0.57, alpha: 1)
        addSolid(size: [16, 0.2, 20], position: [0, -0.1, -4], color: paper)
        addSolid(size: [16, 2.4, 0.3], position: [0, 1.2, -14], color: sage)
        addSolid(size: [16, 2.4, 0.3], position: [0, 1.2, 6], color: sage)
        addSolid(size: [0.3, 2.4, 20], position: [-8, 1.2, -4], color: sage)
        addSolid(size: [0.3, 2.4, 20], position: [8, 1.2, -4], color: sage)
        var rng = SystemRandomNumberGenerator()
        let layout = state.stage.layout(variant: state.variant, using: &rng)
        for obstacle in layout.obstacles {
            addSolid(size: obstacle.size, position: obstacle.position, color: coral)
            obstacles.append((obstacle.position, obstacle.size))
        }
        for position in layout.targets {
            let enemy = EnemyVisual(kind: state.stage.kind, position: position, variant: state.variant)
            root.addChild(enemy.entity)
            enemies.append(enemy)
            targets.append(enemy.entity)
        }
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        move = .zero
        sound.stop()
        view.scene.anchors.removeAll()
    }

    func setActive(_ active: Bool) {
        move = .zero
        lastFrame = 0
        displayLink?.isPaused = !active
        if !active { sound.stop() }
        if active { state.tick() }
    }

    @objc private func frame(_ link: CADisplayLink) {
        state.tick()
        guard state.phase == .game || state.phase == .resolution else { move = .zero; return }
        let dt = lastFrame == 0 ? 0 : Float(min(link.timestamp - lastFrame, 0.05))
        lastFrame = link.timestamp
        elapsed += dt
        for enemy in enemies { enemy.update(time: elapsed, reducedMotion: UIAccessibility.isReduceMotionEnabled) }
        guard state.phase == .game else { move = .zero; return }
        let input = simd_length(move) > 1 ? simd_normalize(move) : move
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        let forward = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
        let delta = (right * input.x + forward * input.y) * dt * 2.4
        var position = camera.position
        let x = SIMD3<Float>(position.x + delta.x, position.y, position.z)
        if canStand(at: x) { position.x = x.x }
        let z = SIMD3<Float>(position.x, position.y, position.z + delta.z)
        if canStand(at: z) { position.z = z.z }
        camera.position = position
    }

    func canStand(at point: SIMD3<Float>) -> Bool {
        guard abs(point.x) < 7.5, point.z > -13.5, point.z < 5.5 else { return false }
        return !obstacles.contains { abs(point.x - $0.center.x) < $0.size.x / 2 + 0.25 && abs(point.z - $0.center.z) < $0.size.z / 2 + 0.25 }
    }

    func look(delta: CGSize) {
        guard state.phase == .game else { return }
        yaw -= Float(delta.width) * 0.005
        pitch = min(1.1, max(-1.2, pitch - Float(delta.height) * 0.005))
        orientCamera()
    }

    private func orientCamera() {
        camera.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
    }

    func shoot() {
        guard state.fire() else { return }
        sound.play()
        if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true { haptic.impactOccurred(intensity: 0.2) }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let ray = view.ray(through: center),
              let hit = view.scene.raycast(origin: ray.origin, direction: ray.direction, length: 40, query: .nearest).first,
              let target = hit.entity as? ModelEntity,
              let targetID = targets.firstIndex(where: { $0 === target }) else { return }
        guard state.registerHit(targetID: targetID) else { return }
        sound.playHit(state.stage.kind.material)
        enemies[targetID].react(hits: state.targetHits[targetID], time: elapsed, playerPosition: camera.position)
        enemies[targetID].update(time: elapsed, reducedMotion: UIAccessibility.isReduceMotionEnabled)
        if state.targetHits[targetID] == state.stage.kind.hitsToResolve {
            sound.playResolution(final: state.isFinalStage && state.isCleared)
            if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true { haptic.impactOccurred(intensity: 0.6) }
        }
        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .announcement, argument: state.message) }
    }

    func reload() { state.reload() }

    private func addSolid(size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor) {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, roughness: 1, isMetallic: false)])
        entity.position = position
        entity.generateCollisionShapes(recursive: false)
        entity.physicsBody = PhysicsBodyComponent(shapes: entity.collision!.shapes, mass: 1, mode: .static)
        root.addChild(entity)
    }

}
