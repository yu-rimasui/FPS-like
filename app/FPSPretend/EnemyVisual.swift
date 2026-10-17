import RealityKit
import UIKit
import simd

@MainActor
final class EnemyVisual {
    let entity = ModelEntity()
    let kind: EnemyKind
    let origin: SIMD3<Float>
    private let variant: Int
    private var figure = Entity()
    private var hits = 0
    private var hitAt: Float = -10
    private var resolvedFacing: Float = 0
    private var resolved: Bool { hits >= kind.hitsToResolve }
    private var progress: Float { Float(hits) / Float(kind.hitsToResolve) }

    init(kind: EnemyKind, position: SIMD3<Float>, variant: Int) {
        self.kind = kind
        self.origin = position
        self.variant = variant
        entity.position = position
        entity.name = kind.details.name
        let shape = ShapeResource.generateBox(size: kind.hitBox)
        entity.collision = CollisionComponent(shapes: [shape])
        entity.physicsBody = PhysicsBodyComponent(shapes: [shape], mass: 1, mode: .kinematic)
        rebuild()
    }

    func react(hits: Int, time: Float, playerPosition: SIMD3<Float>) {
        self.hits = hits
        hitAt = time
        resolvedFacing = atan2(playerPosition.x - origin.x, playerPosition.z - origin.z)
        rebuild()
        if resolved { entity.collision = nil; entity.physicsBody = nil }
    }

    func update(time: Float, reducedMotion: Bool) {
        let pulse = reducedMotion ? 0 : max(0, 1 - (time - hitAt) * 4)
        let wave = reducedMotion || resolved ? Float.zero : sin(time * (1.4 + Float(kind.rawValue) * 0.18))
        var position = origin
        var scale = SIMD3<Float>(repeating: 1)
        var angle: Float = 0
        switch kind {
        case .notification:
            position.y += wave * 0.035 + pulse * 0.1
            scale = [1 + pulse * 0.15, (resolved ? 0.75 : 1) - pulse * 0.15, 1]
        case .duvet:
            scale = SIMD3(repeating: resolved ? 1 : 1 + progress * 0.2 + wave * 0.025)
        case .loading:
            if !resolved { figure.orientation = simd_quatf(angle: reducedMotion ? 0 : time * 1.8, axis: [0, 0, 1]) }
        case .cable: angle = wave * 0.08 * (1 - progress)
        case .mail: position.y += abs(wave) * 0.035 + pulse * 0.08
        case .calendar: angle = wave * 0.035
        case .battery: angle = resolved ? resolvedFacing : wave * 0.05; position.y += pulse * 0.07
        case .password: position.x += wave * 0.08
        case .task: angle = wave * 0.04; scale = SIMD3(repeating: 1 + pulse * 0.08)
        case .dragon:
            position.x += wave * 0.16
            position.y += abs(wave) * 0.06
            scale = SIMD3(repeating: resolved ? 0.38 : 1 + pulse * 0.07)
        }
        entity.position = position
        entity.scale = scale
        entity.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
        for (index, part) in figure.children.enumerated() {
            if part.name == "burst" || part.name == "paper" {
                let age = max(0, time - hitAt)
                part.isEnabled = !reducedMotion && age < 0.6
                part.position.y = 0.25 + age * 0.7
                part.scale = SIMD3(repeating: max(0, 1 - age / 0.6))
            } else if part.name == "flame" && !reducedMotion {
                part.position.z = 0.65 + (time * 0.8 + Float(index) * 0.16).truncatingRemainder(dividingBy: 0.5)
            }
        }
    }

    private var color: UIColor {
        let colors: [UIColor] = [.systemTeal, .systemPink, .systemBlue, .systemYellow, .systemIndigo,
                                 .systemRed, .systemMint, .systemOrange, .systemPurple, .systemOrange]
        return colors[kind.rawValue].withAlphaComponent(1)
    }

    @discardableResult private func box(_ size: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor, radius: Float = 0.025) -> ModelEntity {
        let part = ModelEntity(mesh: .generateBox(size: size, cornerRadius: radius),
                               materials: [SimpleMaterial(color: color, roughness: 0.85, isMetallic: false)])
        part.position = position
        figure.addChild(part)
        return part
    }

    @discardableResult private func ball(_ radius: Float, _ position: SIMD3<Float>, _ color: UIColor) -> ModelEntity {
        let part = ModelEntity(mesh: .generateSphere(radius: radius),
                               materials: [SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)])
        part.position = position
        figure.addChild(part)
        return part
    }

    private func text(_ value: String, _ position: SIMD3<Float>, size: Float = 0.14, color: UIColor = .darkGray) {
        let mesh = MeshResource.generateText(value, extrusionDepth: 0.002,
            font: .systemFont(ofSize: CGFloat(size), weight: .bold))
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
        let bounds = label.visualBounds(relativeTo: label)
        label.position = position - SIMD3(bounds.center.x, 0, 0)
        entity.addChild(label)
    }

    private func eyes(y: Float = 0.1, z: Float = 0.35) {
        for x: Float in [-0.13, 0.13] {
            _ = box([0.075, resolved ? 0.035 : 0.085, 0.03], [x, y, z], .darkGray, radius: 0)
        }
    }

    private func rebuild() {
        entity.children.removeAll()
        figure = Entity()
        entity.addChild(figure)
        let accent = variant == 1 ? UIColor.systemYellow : (variant == 2 ? .systemMint : .white)
        switch kind {
        case .notification:
            ball(0.47, [0, -0.05, 0], color).scale = [1, 0.7, 1]
            eyes(y: 0.02, z: 0.43)
            if !resolved {
                ball(0.17, [0.36, 0.28, 0.24], .systemRed)
                text(variant == 2 ? "999" : "99+", [0.36, 0.24, 0.42], size: 0.095, color: .white)
            } else {
                for x: Float in [-0.5, 0.5] { box([0.09, 0.09, 0.09], [x, 0.25, 0.2], .systemRed).name = "burst" }
                text("通知 0", [0, 0.4, 0.2])
            }
        case .duvet:
            _ = box([1, 0.28, 1.1], [0, 0, 0], color, radius: 0.1)
            _ = box([0.75, 0.16, 0.3], [0, 0.19, -0.35], accent, radius: 0.07)
            eyes(y: 0.04, z: 0.56)
            if resolved {
                figure.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                figure.position.y = 0.25
                _ = box([0.24, 0.3, 0.12], [0.65, 0, 0], .brown)
                text("起床", [0, 0.7, 0.4])
            } else { text("あと5分", [0, 0.35, 0.45]) }
        case .loading:
            for i in 0..<8 {
                let angle = Float(i) * .pi / 4
                let part = box([0.13, 0.23, 0.12], [sin(angle) * 0.37, cos(angle) * 0.37, 0],
                               Float(i) < progress * 8 ? .systemMint : color)
                part.orientation = simd_quatf(angle: -angle, axis: [0, 0, 1])
            }
            text("\(hits * 100 / kind.hitsToResolve)%", [0, -0.07, 0.18], size: 0.18)
        case .cable:
            var points: [SIMD3<Float>] = []
            for i in 0..<9 {
                let t = Float(i) / 8
                let angle = t * .pi * 2
                let point: SIMD3<Float> = resolved ? [sin(angle) * 0.44, 0, cos(angle) * 0.34] :
                    [(t - 0.5) * 1.1, sin(t * .pi * 4) * 0.12 * (1 - progress), sin(t * .pi * 3) * 0.3 * (1 - progress)]
                ball(0.11, point, color)
                points.append(point)
            }
            for i in 0..<points.count - 1 {
                let middle = (points[i] + points[i + 1]) / 2
                let segment = box([0.14, 0.14, simd_distance(points[i], points[i + 1])], middle, color)
                segment.look(at: points[i + 1], from: middle, relativeTo: figure)
            }
            _ = box([0.2, 0.15, 0.16], resolved ? [0, 0, 0.4] : [0.6, 0, 0], accent)
            if resolved { text("すっきり", [0, 0.35, 0.4]) }
        case .mail:
            let count = resolved ? 1 : 5 - hits
            for i in 0..<count {
                let part = box([0.75, 0.15, 0.45], [Float(i % 2) * 0.08, Float(i) * 0.16 - 0.35, 0], i.isMultiple(of: 2) ? .white : accent)
                part.orientation = simd_quatf(angle: Float(i % 2) * 0.12, axis: [0, 1, 0])
            }
            eyes(y: 0, z: 0.25)
            for i in 0..<hits {
                let part = box([0.18, 0.24, 0.02], [Float(i - 1) * 0.4, 0.4, 0.2], .white)
                part.name = "paper"
                part.orientation = simd_quatf(angle: Float(i - 1) * 0.3, axis: [0, 0, 1])
            }
            text(resolved ? "承知しました" : "未読", [0, 0.5, 0.3], size: 0.12)
        case .calendar:
            _ = box([0.9, 1, 0.16], [0, 0, 0], .white)
            _ = box([0.92, 0.18, 0.19], [0, 0.42, 0], color)
            text(["月", "火", "水", "木", "金"][hits], [0, -0.15, 0.1], size: 0.38)
            if resolved {
                for x: Float in [-0.21, 0.21] { _ = box([0.3, 0.16, 0.07], [x, 0.22, 0.15], .black) }
                _ = box([0.16, 0.04, 0.08], [0, 0.24, 0.15], .black)
            }
        case .battery:
            _ = box([0.62, 0.65, 0.4], [0, -0.18, 0], color)
            _ = box([0.55, 0.36, 0.4], [0, 0.4, 0], accent)
            eyes(y: 0.42, z: 0.22)
            _ = box([0.4, 0.18, 0.03], [0, -0.1, 0.22], .darkGray)
            _ = box([max(0.025, progress * 0.35), 0.12, 0.04], [-0.17 + progress * 0.175, -0.1, 0.24], .systemGreen)
            text("\(min(100, 1 + hits * 25))%", [0, 0.7, 0.25])
            if resolved {
                for i in 0..<4 { ball(0.06, [0.4, -0.1, Float(i) * 0.2], .systemYellow) }
                text("あなたも100%", [0, 0.1, 0.75], size: 0.11)
            }
        case .password:
            for x: Float in [-0.5, 0.5] { _ = box([0.18, 1.1, 0.25], [x, 0, 0], color) }
            _ = box([1.2, 0.18, 0.25], [0, 0.56, 0], color)
            _ = box([0.72, 0.9, 0.12], [resolved ? 0.75 : 0, -0.06, 0], accent)
            if !resolved { text(["8文字", "記号!", "大文字!", "前と別!"][hits], [0, 0.1, 0.12]) }
            else { text("顔パス", [0, 0.15, 0.15], size: 0.2) }
        case .task:
            for i in 0..<min(4, hits + 1) {
                let x = Float(i % 2) * 0.55 - 0.25
                let y = Float(i / 2) * 0.45 - 0.2
                let part = box([0.5, 0.38, 0.12], [x, y, Float(i) * 0.03], resolved ? .systemMint : color)
                part.orientation = simd_quatf(angle: Float(i - 1) * 0.1, axis: [0, 0, 1])
            }
            text(resolved ? "明日でOK" : "ちょっとだけ", [0, 0.55, 0.3], size: 0.12)
        case .dragon:
            ball(0.4, [0, -0.1, 0], color).scale = [1, 0.9, 1.25]
            _ = box([0.5, 0.42, 0.5], [0, 0.25, 0.2], color, radius: 0.08)
            for x: Float in [-0.21, 0.21] {
                let horn = box([0.1, 0.3, 0.1], [x, 0.54, 0.05], accent)
                horn.orientation = simd_quatf(angle: x, axis: [0, 0, 1])
            }
            for x: Float in [-0.52, 0.52] {
                let wing = box([0.5, 0.06, 0.5], [x, 0.12, -0.1], .systemMint)
                wing.orientation = simd_quatf(angle: x, axis: [0, 0, 1])
            }
            eyes(y: 0.3, z: 0.46)
            for i in 0..<3 { ball(Float(3 - i) * 0.075, [0, -0.15, -0.5 - Float(i) * 0.2], color) }
            if !resolved {
                for i in 0..<3 { ball(0.09, [Float(i - 1) * 0.16, 0.04, 0.65], .systemYellow).name = "flame" }
                text("本日中", [0, 0.4, 0.7], size: 0.16, color: .systemRed)
            } else { text("来週でOK", [0, 0.9, 0.6], size: 0.22) }
        }
        figure.scale.x = variant == 1 ? 0.94 : (variant == 2 ? 1.06 : 1)
        if resolved && kind != .dragon { text("解決!", [0, 0.85, 0.3], size: 0.13, color: .systemTeal) }
    }
}
