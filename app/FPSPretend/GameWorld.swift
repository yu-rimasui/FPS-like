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
    private var solids: [ModelEntity] = []
    private var movingObstacles: [(definition: Stage.Obstacle, entity: Entity)] = []
    private(set) var targets: [ModelEntity] = []
    private(set) var enemies: [EnemyVisual] = []
    private var elapsed: Float = 0
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private var stopped = false
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
            addObstacle(obstacle, color: coral)
        }
        for (id, position) in layout.targets.enumerated() {
            let enemy = EnemyVisual(motion: state.stage.motions[id], position: position,
                                    color: EnemyVisual.colors.randomElement(using: &rng)!, requiredHits: state.stage.hitsRequired(for: id))
            root.addChild(enemy.entity)
            enemies.append(enemy)
            targets.append(enemy.entity)
        }
        updateScene(time: 0, reducedMotion: UIAccessibility.isReduceMotionEnabled)
    }

    func start() {
        guard displayLink == nil, !stopped else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        stopped = true
        displayLink?.invalidate()
        displayLink = nil
        move = .zero
        sound.stop()
        view.scene.anchors.removeAll()
    }

    func setActive(_ active: Bool) {
        guard !stopped else { return }
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
        updateScene(time: Float(ProcessInfo.processInfo.systemUptime - startedAt), reducedMotion: UIAccessibility.isReduceMotionEnabled)
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
        return !solids.contains { solid in
            let bounds = solid.visualBounds(relativeTo: nil)
            return bounds.max.y > 0.1 && bounds.min.y < 1.8 &&
                point.x > bounds.min.x - 0.25 && point.x < bounds.max.x + 0.25 &&
                point.z > bounds.min.z - 0.25 && point.z < bounds.max.z + 0.25
        }
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
        guard !stopped, state.fire() else { return }
        updateScene(time: Float(ProcessInfo.processInfo.systemUptime - startedAt), reducedMotion: UIAccessibility.isReduceMotionEnabled)
        sound.play()
        if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true { haptic.impactOccurred(intensity: 0.2) }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let ray = view.ray(through: center),
              let hit = view.scene.raycast(origin: ray.origin, direction: ray.direction, length: 40, query: .nearest).first,
              let target = hit.entity as? ModelEntity,
              let targetID = targets.firstIndex(where: { $0 === target }) else { return }
        let required = state.stage.hitsRequired(for: targetID)
        let previousStep = state.targetHits[targetID] * 4 / required
        guard state.registerHit(targetID: targetID) else { return }
        sound.playHit(state.stage.kind.material)
        enemies[targetID].react(hits: state.targetHits[targetID], time: elapsed)
        enemies[targetID].update(time: elapsed, reducedMotion: UIAccessibility.isReduceMotionEnabled)
        if state.targetHits[targetID] == required {
            sound.playResolution(final: state.isFinalStage && state.isCleared)
            if UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true { haptic.impactOccurred(intensity: 0.6) }
        } else if state.targetHits[targetID] * 4 / required > previousStep {
            sound.playMilestone()
        }
        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .announcement, argument: state.message) }
    }

    func reload() { state.reload() }

    @discardableResult private func addSolid(size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, roughness: 1, isMetallic: false)])
        entity.position = position
        entity.generateCollisionShapes(recursive: false)
        entity.physicsBody = PhysicsBodyComponent(shapes: entity.collision!.shapes, mass: 1, mode: .static)
        root.addChild(entity)
        solids.append(entity)
        return entity
    }

    private func addObstacle(_ obstacle: Stage.Obstacle, color: UIColor) {
        let container = Entity()
        container.name = "obstacle.\(obstacle.kind)"
        container.position = obstacle.position
        root.addChild(container)
        switch obstacle.kind {
        case .wall, .maze:
            addSolid(size: obstacle.size, position: obstacle.position, color: color)
        case .windmill:
            addSolid(size: [0.18, obstacle.position.y, 0.18], position: [obstacle.position.x, obstacle.position.y / 2, obstacle.position.z], color: .brown)
            for angle: Float in [0, .pi / 2] {
                let blade = addSolid(size: obstacle.size, position: .zero, color: color)
                container.addChild(blade)
                blade.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
                blade.physicsBody = nil
            }
            movingObstacles.append((obstacle, container))
        case .ball, .meteor:
            let radius = obstacle.size.x / 2
            let ball = ModelEntity(mesh: .generateSphere(radius: radius), materials: [SimpleMaterial(color: obstacle.kind == .meteor ? .systemBrown : color, roughness: 1, isMetallic: false)])
            ball.collision = CollisionComponent(shapes: [.generateSphere(radius: radius)])
            container.addChild(ball)
            solids.append(ball)
            let spot = ModelEntity(mesh: .generateSphere(radius: radius * 0.24), materials: [SimpleMaterial(color: .white, roughness: 1, isMetallic: false)])
            spot.position = [0, 0, radius * 0.9]
            ball.addChild(spot)
            movingObstacles.append((obstacle, container))
        }
    }

    func updateScene(time: Float, reducedMotion: Bool) {
        guard !stopped else { return }
        elapsed = time
        for enemy in enemies { enemy.update(time: time, reducedMotion: reducedMotion) }
        for (definition, entity) in movingObstacles {
            switch definition.kind {
            case .windmill:
                entity.orientation = simd_quatf(angle: time * 0.8, axis: [0, 0, 1])
            case .ball:
                let travel = sin(time * 0.8) * 1.2
                entity.position.x = definition.position.x + travel
                entity.orientation = simd_quatf(angle: -travel / (definition.size.x / 2), axis: [0, 0, 1])
            case .meteor:
                entity.position.y = definition.position.y + 5 * (1 - (time * 0.2 + abs(definition.position.x) * 0.1).truncatingRemainder(dividingBy: 1))
                entity.orientation = simd_quatf(angle: reducedMotion ? 0 : time, axis: [1, 0, 1])
            case .wall, .maze: break
            }
        }
    }
}
