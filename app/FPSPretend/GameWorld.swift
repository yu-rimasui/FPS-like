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
    private var routes: [[SIMD2<Float>]] = []
    private var navigationBounds: [BoundingBox] = []
    private var rng = SystemRandomNumberGenerator()
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
        camera.position = state.stage.playerStart
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
        addSolid(size: [16.3, 2.4, 0.3], position: [0, 1.2, -14], color: sage)
        addSolid(size: [16.3, 2.4, 0.3], position: [0, 1.2, 6], color: sage)
        addSolid(size: [0.3, 2.4, 20.3], position: [-8, 1.2, -4], color: sage)
        addSolid(size: [0.3, 2.4, 20.3], position: [8, 1.2, -4], color: sage)
        let layout = state.stage.layout(variant: state.variant, using: &rng)
        for obstacle in layout.obstacles {
            addObstacle(obstacle, color: coral)
        }
        navigationBounds = layout.obstacles.map { obstacle in
            var half = obstacle.size / 2
            // Reserve the moving obstacle's swept area instead of walking into its next position.
            switch obstacle.kind {
            case .windmill: half.x = hypot(half.x, half.y)
            case .ball: half *= 1.14; half.x += 1.2
            case .meteor: half *= 1.14
            case .wall, .maze: break
            }
            return BoundingBox(min: obstacle.position - half, max: obstacle.position + half)
        }
        for (id, position) in layout.targets.enumerated() {
            let enemy = EnemyVisual(motion: state.stage.motions[id], position: position,
                                    color: EnemyVisual.colors.randomElement(using: &rng)!, requiredHits: state.stage.hitsRequired(for: id))
            root.addChild(enemy.entity)
            enemies.append(enemy)
            targets.append(enemy.entity)
            routes.append([])
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
        let bounds = solids.map { $0.visualBounds(relativeTo: nil) }.filter { $0.max.y > 0.1 && $0.min.y < 1.8 }
        return Self.canTravel(from: [point.x, point.z], to: [point.x, point.z], clearance: 0.25, bounds: bounds)
    }

    static func canTravel(from: SIMD2<Float>, to: SIMD2<Float>, clearance: Float, bounds: [BoundingBox]) -> Bool {
        for point in [from, to] {
            guard abs(point.x) < 7.75 - clearance, point.y > -13.75 + clearance, point.y < 5.75 - clearance else { return false }
        }
        let low = simd_min(from, to) - SIMD2(repeating: clearance)
        let high = simd_max(from, to) + SIMD2(repeating: clearance)
        return !bounds.contains { low.x < $0.max.x && high.x > $0.min.x && low.y < $0.max.z && high.y > $0.min.z }
    }

    func canRoam(from: SIMD2<Float>, to: SIMD2<Float>) -> Bool {
        Self.canTravel(from: from, to: to, clearance: 1.05, bounds: navigationBounds)
    }

    private func moveEnemies(delta: Float) {
        for (id, enemy) in enemies.enumerated() where enemy.entity.isEnabled && enemy.motion.speed > 0 {
            var position = SIMD2<Float>(enemy.entity.position.x, enemy.entity.position.z)
            if routes[id].isEmpty {
                routes[id] = Self.roamingRoute(from: position, using: &rng) { from, to in
                    canRoam(from: from, to: to)
                }
            }
            var distance = enemy.motion.speed * delta
            while distance > 0, let next = routes[id].last {
                let direction = next - position
                let length = simd_length(direction)
                if length < 0.001 { routes[id].removeLast(); continue }
                let step = min(distance, length)
                let destination = position + direction / length * step
                guard canRoam(from: position, to: destination) else {
                    routes[id].removeAll()
                    break
                }
                enemy.entity.orientation = simd_quatf(angle: atan2(direction.x, direction.y), axis: [0, 1, 0])
                position = destination
                distance -= step
                // Finish a segment before turning so a frame cannot cut across a wall corner.
                if step == length { routes[id].removeLast(); break }
            }
            enemy.entity.position.x = position.x
            enemy.entity.position.z = position.y
        }
    }

    static func roamingRoute<R: RandomNumberGenerator>(from position: SIMD2<Float>, using rng: inout R,
                                                       canTravel: (SIMD2<Float>, SIMD2<Float>) -> Bool) -> [SIMD2<Float>] {
        let cell: Float = 0.5
        func point(_ node: SIMD2<Int>) -> SIMD2<Float> { SIMD2<Float>(Float(node.x), Float(node.y)) * cell }
        let nearest = SIMD2<Int>(Int((position.x / cell).rounded()), Int((position.y / cell).rounded()))
        let starts = (-1...1).flatMap { x in (-1...1).map { nearest &+ SIMD2(x, $0) } }
            .sorted { simd_distance_squared(point($0), position) < simd_distance_squared(point($1), position) }
        guard let start = starts.first(where: { canTravel(position, point($0)) }) else { return [] }
        let directions: [SIMD2<Int>] = [[1, 0], [-1, 0], [0, 1], [0, -1]].shuffled(using: &rng)
        var parents = [start: start]
        var queue = [start]
        var index = 0
        // A small four-neighbour grid is enough for the maze; no navigation mesh or search library.
        while index < queue.count {
            let node = queue[index]
            index += 1
            for direction in directions {
                let next = node &+ direction
                guard parents[next] == nil, canTravel(point(node), point(next)) else { continue }
                parents[next] = node
                queue.append(next)
            }
        }
        guard queue.count > 1 else { return [] }
        let low = queue.reduce(start) { simd_min($0, $1) }
        let high = queue.reduce(start) { simd_max($0, $1) }
        let centre = (point(low) + point(high)) / 2
        let corner = SIMD2(position.x < centre.x ? high.x : low.x, position.y < centre.y ? high.y : low.y)
        func score(_ node: SIMD2<Int>) -> Int { abs(node.x - corner.x) + abs(node.y - corner.y) }
        let best = queue.map(score).min()!
        let candidates = queue.filter { $0 != start && score($0) <= best + 2 }
        guard var node = candidates.randomElement(using: &rng) else { return [] }
        var route = [point(node)]
        while node != start {
            node = parents[node]!
            route.append(point(node))
        }
        return route
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
        let delta = min(0.1, max(0, time - elapsed))
        elapsed = time
        if state.phase == .game { moveEnemies(delta: delta) }
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
