import Foundation

enum EnemyKind: Int, CaseIterable {
    case resting, walking, dancing, laughing, flying

    var details: (name: String, instruction: String, endings: [String]) {
        switch self {
        case .resting: return ("ひと休みの人形", "横倒しの2体と、歩く1体。壁を回って狙おう。", ["休憩、おしまい", "よく休めました", "そろそろ起きます"])
        case .walking: return ("歩く・走る人形", "歩く2体と走る2体。風車の羽の隙間を狙おう。", ["お散歩、おしまい", "走りきりました", "ひと息つきましょう"])
        case .dancing: return ("踊る人形", "踊る4体。転がるボールをよけて狙おう。", ["踊りきりました", "アンコールはまた今度", "いいリズムでした"])
        case .laughing: return ("笑い転げる人形", "笑い転げる4体。迷路を回って探そう。", ["笑いすぎました", "ひとまず深呼吸", "楽しい時間でした"])
        case .flying: return ("スキップ・空飛ぶ人形", "スキップ2体と空飛ぶ2体。隕石の向こうを狙おう。", ["着地しました", "空の散歩、おしまい", "また遊びましょう"])
        }
    }

    func completion(variant: Int) -> String { details.endings[variant] }
    func reaction(step: Int) -> String { ["命中！", "いい調子", "あと少し", "もうひと息"][min(3, max(0, step))] }
    var material: HitMaterial { .cloth }
}

enum EnemyMotion: CaseIterable {
    case lying, sliding, walking, running, dancing, laughing, skipping, flying

    var isLying: Bool { self == .lying || self == .sliding || self == .laughing }
    var height: Float { isLying ? 0.28 : (self == .flying ? 2.2 : 0.94) }
}

struct Stage {
    struct Obstacle {
        enum Kind { case wall, windmill, ball, maze, meteor }
        let kind: Kind
        let position: SIMD3<Float>
        let size: SIMD3<Float>
    }

    let kind: EnemyKind
    let motions: [EnemyMotion]
    let targets: [SIMD3<Float>]
    let obstacles: [Obstacle]
    let timeLimit = 60
    let hitBudget = 15

    var name: String { kind.details.name }
    func hitsRequired(for targetID: Int) -> Int { ((hitBudget + targets.count * 5 - 1) / (targets.count * 5)) * 5 }
    var requiredHits: Int { hitsRequired(for: 0) * targets.count }
    var requiredTargets: Int { targets.count }
    var goal: String { "60秒以内に全\(targets.count)体・各\(hitsRequired(for: 0))回命中でクリア" }

    func layout<R: RandomNumberGenerator>(variant: Int, using rng: inout R) -> (targets: [SIMD3<Float>], obstacles: [Obstacle]) {
        let mirror: Float = variant.isMultiple(of: 2) ? 1 : -1
        let boxes = obstacles.map { Obstacle(kind: $0.kind, position: [$0.position.x * mirror, $0.position.y, $0.position.z], size: $0.size) }
        var positions: [SIMD3<Float>] = []
        for (id, target) in targets.enumerated() {
            let base = SIMD3<Float>(target.x * mirror, motions[id].height, target.z)
            var point = base
            if variant != 0 {
                point.x += Float.random(in: -0.2...0.2, using: &rng)
                point.z += Float.random(in: -0.2...0.2, using: &rng)
            }
            let blocked = boxes.contains { abs(point.x - $0.position.x) < $0.size.x / 2 + 0.8 && abs(point.z - $0.position.z) < $0.size.z / 2 + 0.8 }
            let crowded = positions.contains { abs(point.x - $0.x) < 1.6 && abs(point.z - $0.z) < 1.6 }
            if blocked || crowded || abs(point.x) > 6.5 || point.z < -12.5 || point.z > 4 { point = base }
            positions.append(point)
        }
        return (positions, boxes)
    }

    static let all: [Stage] = [
        Stage(kind: .resting, motions: [.lying, .sliding, .walking],
              targets: [[0, 0.28, -2], [-3, 0.28, -6], [3, 0.94, -5]],
              obstacles: [Obstacle(kind: .wall, position: [-3, 0.8, -3], size: [2.6, 1.6, 0.3]),
                          Obstacle(kind: .wall, position: [3, 0.8, -9], size: [2.6, 1.6, 0.3])]),
        Stage(kind: .walking, motions: [.walking, .walking, .running, .running],
              targets: [[-3, 0.94, -2], [3, 0.94, -2], [-3, 0.94, -8], [3, 0.94, -8]],
              obstacles: [Obstacle(kind: .windmill, position: [-2, 1.8, -5], size: [3.2, 0.22, 0.25]),
                          Obstacle(kind: .windmill, position: [2, 1.8, -5], size: [3.2, 0.22, 0.25])]),
        Stage(kind: .dancing, motions: [.dancing, .dancing, .dancing, .dancing],
              targets: [[-3, 0.94, -2], [3, 0.94, -2], [-3, 0.94, -9], [3, 0.94, -9]],
              obstacles: [Obstacle(kind: .ball, position: [-2, 0.65, -5], size: [1.3, 1.3, 1.3]),
                          Obstacle(kind: .ball, position: [2, 0.8, -6], size: [1.6, 1.6, 1.6])]),
        Stage(kind: .laughing, motions: [.laughing, .laughing, .laughing, .laughing],
              targets: [[-5, 0.28, -3], [5, 0.28, -3], [-4, 0.28, -10], [4, 0.28, -10]],
              obstacles: [Obstacle(kind: .maze, position: [0, 0.9, -3], size: [0.3, 1.8, 4]),
                          Obstacle(kind: .maze, position: [-3, 0.9, -6], size: [4.5, 1.8, 0.3]),
                          Obstacle(kind: .maze, position: [3, 0.9, -7], size: [4.5, 1.8, 0.3]),
                          Obstacle(kind: .maze, position: [0, 0.9, -10], size: [0.3, 1.8, 4])]),
        Stage(kind: .flying, motions: [.skipping, .skipping, .flying, .flying],
              targets: [[-3, 0.94, -2], [3, 0.94, -2], [-3, 2.2, -9], [3, 2.2, -9]],
              obstacles: [Obstacle(kind: .meteor, position: [-2, 0.7, -5], size: [1.4, 1.4, 1.4]),
                          Obstacle(kind: .meteor, position: [2, 0.9, -6], size: [1.8, 1.8, 1.8])])
    ]
}
