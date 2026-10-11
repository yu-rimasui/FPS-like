import RealityKit
import UIKit
import simd

@MainActor
final class GameWorld: NSObject {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    let camera = PerspectiveCamera()
    private let root = AnchorEntity(world: .zero)
    private let state: GameState
    private var displayLink: CADisplayLink?
    private var lastFrame = 0.0
    private var yaw: Float = 0
    private var pitch: Float = -0.26
    var move = SIMD2<Float>.zero
    private var obstacles: [(center: SIMD3<Float>, size: SIMD3<Float>)] = []
    private(set) var targets: [ModelEntity] = []

    init(state: GameState) {
        self.state = state
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
        for (position, size) in [(SIMD3<Float>(-3, 0.6, -3), SIMD3<Float>(1.6, 1.2, 1.6)),
                                 (SIMD3<Float>(3.2, 0.4, -6), SIMD3<Float>(1.8, 0.8, 1.8)),
                                 (SIMD3<Float>(-4.5, 0.8, -10), SIMD3<Float>(2, 1.6, 2))] {
            addSolid(size: size, position: position, color: coral)
            obstacles.append((position, size))
        }
        for (index, position) in [SIMD3<Float>(0, 0.28, -2), [-2, 0.28, -6], [2, 0.28, -3.5], [0.5, 0.28, -9]].enumerated() {
            let target = makeTarget(color: index.isMultiple(of: 2) ? sage : coral)
            target.position = position
            target.name = "target"
            root.addChild(target)
            targets.append(target)
        }
    }

    func start() {
        state.start()
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        move = .zero
        view.scene.anchors.removeAll()
    }

    func setActive(_ active: Bool) {
        move = .zero
        lastFrame = 0
        displayLink?.isPaused = !active
        if active { state.tick() }
    }

    @objc private func frame(_ link: CADisplayLink) {
        state.tick()
        guard state.phase == .game else { move = .zero; return }
        let dt = lastFrame == 0 ? 0 : Float(min(link.timestamp - lastFrame, 0.05))
        lastFrame = link.timestamp
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

    private func canStand(at point: SIMD3<Float>) -> Bool {
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
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let ray = view.ray(through: center),
              let hit = view.scene.raycast(origin: ray.origin, direction: ray.direction, length: 40, query: .nearest).first,
              let target = hit.entity as? ModelEntity, target.name == "target" else { return }
        state.registerHit()
        target.applyImpulse(ray.direction * 2, at: hit.position, relativeTo: nil)
    }

    func reload() { state.reload() }

    private func addSolid(size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor) {
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, roughness: 1, isMetallic: false)])
        entity.position = position
        entity.generateCollisionShapes(recursive: false)
        entity.physicsBody = PhysicsBodyComponent(shapes: entity.collision!.shapes, mass: 1, mode: .static)
        root.addChild(entity)
    }

    private func makeTarget(color: UIColor) -> ModelEntity {
        let body = ModelEntity()
        // ponytail: one compound rigid body; no skeleton or independently detached limbs.
        let parts: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([0.6, 0.32, 0.7], [0, 0, 0]), ([0.4, 0.36, 0.4], [0, 0, -0.57]),
            ([0.22, 0.24, 0.65], [-0.44, -0.02, 0]), ([0.22, 0.24, 0.65], [0.44, -0.02, 0]),
            ([0.23, 0.27, 0.6], [-0.17, -0.02, 0.62]), ([0.23, 0.27, 0.6], [0.17, -0.02, 0.62])
        ]
        var shapes: [ShapeResource] = []
        for (size, position) in parts {
            let part = ModelEntity(mesh: .generateBox(size: size), materials: [SimpleMaterial(color: color, roughness: 1, isMetallic: false)])
            part.position = position
            body.addChild(part)
            shapes.append(ShapeResource.generateBox(size: size).offsetBy(translation: position))
        }
        for x: Float in [-0.09, 0.09] {
            let eye = ModelEntity(mesh: .generateBox(size: [0.045, 0.01, 0.065]), materials: [UnlitMaterial(color: .darkGray)])
            eye.position = [x, 0.186, -0.57]
            body.addChild(eye)
        }
        body.collision = CollisionComponent(shapes: shapes)
        body.physicsBody = PhysicsBodyComponent(shapes: shapes, mass: 1.5,
            material: .generate(staticFriction: 0.35, dynamicFriction: 0.25, restitution: 0.15), mode: .dynamic)
        return body
    }
}
