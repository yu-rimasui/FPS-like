import RealityKit
import UIKit
import simd

@MainActor
final class EnemyVisual {
    let entity = ModelEntity()
    let origin: SIMD3<Float>
    let motion: EnemyMotion
    let baseColor: UIColor
    let requiredHits: Int
    private let figure = Entity()
    private var bodyParts: [ModelEntity] = []
    private var limbs: [Entity] = []
    private var shapes: [ShapeResource] = []
    private var hits = 0
    private var hitAt: Float?
    private(set) var isDarkened = false
    var reactionStep: Int { hits * 4 / requiredHits }

    static let colors: [UIColor] = [
        UIColor(red: 0.72, green: 0.84, blue: 0.69, alpha: 1),
        UIColor(red: 0.94, green: 0.75, blue: 0.80, alpha: 1),
        UIColor(red: 0.71, green: 0.82, blue: 0.94, alpha: 1)
    ]

    init(motion: EnemyMotion, position: SIMD3<Float>, color: UIColor, requiredHits: Int) {
        self.motion = motion
        self.origin = position
        self.baseColor = color
        self.requiredHits = requiredHits
        entity.position = position
        entity.addChild(figure)
        // Dimensions and rest positions from the original 4744d69 makeTarget model.
        let parts: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([0.6, 0.32, 0.7], [0, 0, 0]), ([0.4, 0.36, 0.4], [0, 0, -0.57]),
            ([0.22, 0.24, 0.65], [-0.44, -0.02, 0]), ([0.22, 0.24, 0.65], [0.44, -0.02, 0]),
            ([0.23, 0.27, 0.6], [-0.17, -0.02, 0.62]), ([0.23, 0.27, 0.6], [0.17, -0.02, 0.62])
        ]
        for (index, pair) in parts.enumerated() {
            let (size, position) = pair
            let part = ModelEntity(mesh: .generateBox(size: size), materials: [material(darkened: false)])
            part.position = position
            if index >= 2 {
                let joint = Entity()
                joint.position = [position.x, position.y, index < 4 ? -0.28 : 0.32]
                part.position -= joint.position
                figure.addChild(joint)
                joint.addChild(part)
                limbs.append(joint)
            } else { figure.addChild(part) }
            bodyParts.append(part)
            shapes.append(.generateBox(size: size))
        }
        for x: Float in [-0.09, 0.09] {
            let eye = ModelEntity(mesh: .generateBox(size: [0.045, 0.01, 0.065]), materials: [UnlitMaterial(color: .darkGray)])
            eye.position = [x, 0.186, -0.57]
            figure.addChild(eye)
        }
        update(time: 0, reducedMotion: false)
    }

    func react(hits: Int, time: Float) {
        guard entity.isEnabled, hits > self.hits, hits <= requiredHits else { return }
        self.hits = hits
        hitAt = time
        setDarkened(true)
        if hits == requiredHits {
            entity.isEnabled = false
            entity.collision = nil
        }
    }

    func update(time: Float, reducedMotion: Bool) {
        guard entity.isEnabled else { return }
        setDarkened(hitAt.map { time - $0 < 1 } ?? false)
        let phase = time + origin.x * 0.3
        let speed: Float = motion == .running ? 2.2 : 0.8
        var offset = SIMD3<Float>.zero
        var tilt: Float = motion.isLying ? 0 : .pi / 2
        var roll: Float = 0
        var swing: Float = 0
        switch motion {
        case .lying: break
        case .sliding: offset.x = sin(time * 0.8) * 0.8
        case .walking, .running:
            offset.x = sin(time * speed) * 0.8
            if !reducedMotion {
                swing = sin(phase * (motion == .running ? 11 : 5)) * (motion == .running ? 0.95 : 0.4)
                offset.y = abs(sin(phase * (motion == .running ? 11 : 5))) * (motion == .running ? 0.1 : 0.025)
                if motion == .running { tilt -= 0.18 }
            }
        case .dancing:
            if !reducedMotion {
                offset.y = abs(sin(phase * 5)) * 0.16
                roll = sin(phase * 5) * 0.3
                swing = sin(phase * 5) * 0.9
            }
        case .laughing:
            offset.x = sin(time * 1.2) * 0.8
            if !reducedMotion {
                roll = sin(phase * 2.4) * .pi
                offset.y = abs(sin(roll)) * 0.45
                tilt = sin(phase * 9) * 0.15
                swing = sin(phase * 9) * 0.35
            }
        case .skipping:
            offset.x = sin(time * 1.3) * 0.8
            if !reducedMotion {
                offset.y = abs(sin(phase * 5)) * 0.45
                swing = sin(phase * 5) * 0.8
            }
        case .flying:
            offset.x = sin(time * 0.7) * 0.8
            if !reducedMotion {
                offset.y = sin(phase * 2) * 0.18
                roll = sin(phase * 2) * 0.12
                swing = sin(phase * 3) * 0.25
            }
        }
        entity.position = origin + offset
        figure.orientation = simd_quatf(angle: roll, axis: [0, 0, 1]) * simd_quatf(angle: tilt, axis: [1, 0, 0])
        for (index, limb) in limbs.enumerated() {
            let direction: Float = index == 0 || index == 3 ? 1 : -1
            limb.orientation = simd_quatf(angle: swing * direction, axis: [1, 0, 0])
            if motion == .dancing || motion == .flying, index < 2 {
                limb.orientation = simd_quatf(angle: (index == 0 ? -1 : 1) * (motion == .flying ? 1.2 : 0.7), axis: [0, 1, 0]) * limb.orientation
            }
        }
        // Reuse the part meshes for colliders so moving limbs remain shootable.
        let colliders = bodyParts.enumerated().map { index, part in
            shapes[index].offsetBy(rotation: part.orientation(relativeTo: entity), translation: part.position(relativeTo: entity))
        }
        entity.collision = CollisionComponent(shapes: colliders)
    }

    private func material(darkened: Bool) -> SimpleMaterial {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        baseColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let factor: CGFloat = darkened ? 0.6 : 1
        return SimpleMaterial(color: UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha), roughness: 1, isMetallic: false)
    }

    private func setDarkened(_ darkened: Bool) {
        guard darkened != isDarkened else { return }
        isDarkened = darkened
        let value = material(darkened: darkened)
        for part in bodyParts { part.model?.materials = [value] }
    }
}
