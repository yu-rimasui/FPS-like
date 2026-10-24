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

enum EnemyMotion: CaseIterable, Hashable {
    case lying, sliding, walking, running, dancing, laughing, skipping, flying

    static let collectionMotions: [Self] = [.sliding, .walking, .running, .dancing, .laughing, .skipping, .flying]
    // The two lying motions differ only in speed, so they share one encyclopedia entry.
    var collectionMotion: Self { self == .lying ? .sliding : self }
    var collectionDetails: (name: String, description: String) {
        switch self {
        case .lying, .sliding:
            return ("横になってる人形", "「静止してたらつまらない」と開発者に言われ、横になったまま滑る独自技術を習得した。起き上がるという提案は、まだ承認していない。")
        case .walking:
            return ("歩いてる人形", "開発者に「自由に歩いていいよ」と言われたので散歩中。行き先は決めていないが、ちゃんと用事がある顔をしている。")
        case .running:
            return ("走ってる人形", "歩く人形より急いでいるが、締め切りも待ち合わせもない。走る動作を実装された日から、止まる理由を探している。")
        case .dancing:
            return ("踊ってる人形", "音楽がなくても踊れるように作られた。本人にはずっと曲が聞こえているらしい。開発者も曲名は知らない。")
        case .laughing:
            return ("笑い転げる人形", "開発者の仮の冗談がツボに入り、そのまま正式採用された。笑いながら迷路を進むが、出口を知っているから笑っているわけではない。")
        case .skipping:
            return ("スキップする人形", "移動にも楽しさが必要だと主張して、スキップ機能を勝ち取った。毎回ちょっと浮くので、本人は飛行チームへの異動も希望している。")
        case .flying:
            return ("空を飛ぶ人形", "地面が混んでいたので、開発者に高さを変更してもらった。羽も免許もないが、設定上は問題ないと言い張っている。")
        }
    }

    var isLying: Bool { self == .lying || self == .sliding || self == .laughing }
    var speed: Float {
        switch self {
        case .lying: return 0.8
        case .sliding, .dancing: return 1
        case .walking: return 1.2
        case .running: return 2.4
        case .laughing: return 1.4
        case .skipping: return 1.6
        case .flying: return 1.5
        }
    }

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

    var name: String {
        switch kind {
        case .resting: return "壁"
        case .walking: return "風車"
        case .dancing: return "ボール"
        case .laughing: return "迷路"
        case .flying: return "隕石"
        }
    }
    var playerStart: SIMD3<Float> { kind == .laughing ? [1.7, 1.6, 3.8] : [0, 1.6, 3] }
    func hitsRequired(for targetID: Int) -> Int { ((hitBudget + targets.count * 5 - 1) / (targets.count * 5)) * 5 }
    var requiredHits: Int { hitsRequired(for: 0) * targets.count }
    var requiredTargets: Int { targets.count }
    var goal: String { "60秒以内に全\(targets.count)体・各\(hitsRequired(for: 0))回命中でクリア" }

    func layout<R: RandomNumberGenerator>(variant: Int, using rng: inout R) -> (targets: [SIMD3<Float>], obstacles: [Obstacle]) {
        let mirror: Float = kind == .laughing || variant.isMultiple(of: 2) ? 1 : -1
        let boxes = obstacles.map { Obstacle(kind: $0.kind, position: [$0.position.x * mirror, $0.position.y, $0.position.z], size: $0.size) }
        var positions: [SIMD3<Float>] = []
        for (id, target) in targets.enumerated() {
            let base = SIMD3<Float>(target.x * mirror, motions[id].height, target.z)
            var point = base
            if variant != 0 {
                point.x += Float.random(in: -0.2...0.2, using: &rng)
                point.z += Float.random(in: -0.2...0.2, using: &rng)
            }
            let blocked = boxes.contains { abs(point.x - $0.position.x) < $0.size.x / 2 + 1.05 && abs(point.z - $0.position.z) < $0.size.z / 2 + 1.05 }
            let crowded = positions.contains { abs(point.x - $0.x) < 1.6 && abs(point.z - $0.z) < 1.6 }
            if blocked || crowded || abs(point.x) > 6.5 || point.z < -12.5 || point.z > 4 { point = base }
            positions.append(point)
        }
        return (positions, boxes)
    }

    private static let mazeWalls: [Obstacle] = {
        // Reference image: outer wall centres (18, 14)...(496, 492); screen top is -Z.
        let segments: [(SIMD2<Float>, SIMD2<Float>)] = [
            ([108, 104], [220, 104]), ([108, 104], [108, 294]),
            ([18, 262], [108, 262]), ([350, 14], [350, 104]),
            ([316, 104], [405, 104]), ([405, 104], [405, 262]),
            ([204, 200], [310, 200]), ([310, 200], [310, 254]),
            ([310, 254], [405, 254]), ([204, 200], [204, 308]),
            ([204, 308], [257, 308]), ([244, 308], [244, 402]),
            ([108, 402], [264, 402]), ([108, 392], [108, 402]),
            ([405, 355], [405, 402]), ([355, 402], [405, 402]),
            ([380, 402], [380, 492])
        ]
        return segments.map { a, b in
            let start = SIMD2<Float>((a.x - 18) / 478 * 16 - 8, (a.y - 14) / 478 * 20 - 14)
            let end = SIMD2<Float>((b.x - 18) / 478 * 16 - 8, (b.y - 14) / 478 * 20 - 14)
            let centre = (start + end) / 2
            return Obstacle(kind: .maze, position: [centre.x, 0.9, centre.y],
                            size: [abs(end.x - start.x) + 0.36, 1.8, abs(end.y - start.y) + 0.36])
        }
    }()

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
              targets: [[-6.4, 0.28, -12], [6.4, 0.28, -12], [-6.4, 0.28, 3.8], [1.4, 0.28, 0.7]],
              obstacles: mazeWalls),
        Stage(kind: .flying, motions: [.skipping, .skipping, .flying, .flying],
              targets: [[-3, 0.94, -2], [3, 0.94, -2], [-3, 2.2, -9], [3, 2.2, -9]],
              obstacles: [Obstacle(kind: .meteor, position: [-2, 0.7, -5], size: [1.4, 1.4, 1.4]),
                          Obstacle(kind: .meteor, position: [2, 0.9, -6], size: [1.8, 1.8, 1.8])])
    ]
}
