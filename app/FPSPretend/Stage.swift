import Foundation

enum EnemyKind: Int, CaseIterable {
    case notification, duvet, loading, cable, mail, calendar, battery, password, task, dragon

    var details: (name: String, instruction: String, endings: [String]) {
        switch self {
        case .notification: return ("通知スライム", "赤いバッジを撃って、通知を静かにしよう。", ["静かですね", "通知も休憩中です", "既読は気持ちでつけました"])
        case .duvet: return ("あと5分ふとん", "ふくらむふとんを2回ずつ撃って、起こそう。", ["出勤します…", "在宅でした…", "起きました。気持ちだけ。"])
        case .loading: return ("ぐるぐる読み込み", "ぐるぐるを撃って、進捗を100％にしよう。", ["特に何もありませんでした", "読み込み先は休憩でした", "お待たせしただけでした"])
        case .cable: return ("絡まるケーブル蛇", "絡まりを3回ずつ撃って、きれいな輪にしよう。", ["きれいな輪になりました", "ほどいたら、ただの輪でした", "もう絡む予定はありません"])
        case .mail: return ("未読メールゴーレム", "紙の山を撃って、未読を片付けよう。", ["全部、承知しました", "承知したので休みます", "返信は『承知しました』で統一"])
        case .calendar: return ("月曜カレンダー", "箱を回って狙おう。撃つたび金曜に近づく。", ["金曜です。おつかれさま。", "月曜は置いてきました", "週末モードに入りました"])
        case .battery: return ("充電1％ロボ", "ロボを撃って充電。100％まで届けよう。", ["今度はこちらが充電します", "あなたも満タンにしときます", "休憩も充電に含みます"])
        case .password: return ("パスワード門番", "増える条件を撃って、門を開けよう。", ["顔パスでどうぞ", "パスワード、いりませんでした", "合言葉は『おつかれさま』"])
        case .task: return ("「ちょっとだけ」タスク分裂体", "分裂しても同じまとまりを撃つ。4回で片付く。", ["全部、明日でOK", "ちょっとだけ、明日にします", "本日のタスクは解散しました"])
        case .dragon: return ("締切ドラゴン", "『本日中』を4回ずつ撃って、小さくしよう。", ["来週で大丈夫です", "締切のほうが折れました", "急ぎません。お茶にしましょう"])
        }
    }

    var hitsToResolve: Int { [1, 2, 3, 3, 3, 4, 4, 4, 4, 4][rawValue] }
    var material: HitMaterial { [.gel, .cloth, .digital, .rubber, .paper, .paper, .metal, .metal, .paper, .rubber][rawValue] }
    var hitBox: SIMD3<Float> {
        [[1.05, 0.8, 1], [1.15, 0.6, 1.3], [1, 1, 0.4], [1.3, 0.5, 1], [0.95, 1.1, 0.7],
         [1.1, 1.2, 0.4], [0.95, 1.3, 0.7], [1.3, 1.25, 0.5], [1.3, 1, 0.7], [1.5, 1.3, 1.4]][rawValue]
    }
}

struct Stage {
    struct Obstacle {
        let position: SIMD3<Float>
        let size: SIMD3<Float>
    }

    let kind: EnemyKind
    let timeLimit: Int
    let targets: [SIMD3<Float>]
    let obstacles: [Obstacle]

    var name: String { kind.details.name }
    var requiredHits: Int { targets.count * kind.hitsToResolve }
    var requiredTargets: Int { targets.count }
    var goal: String { "\(timeLimit)秒以内に\(targets.count)体を解決（各\(kind.hitsToResolve)回）" }

    func layout<R: RandomNumberGenerator>(variant: Int, using rng: inout R) -> (targets: [SIMD3<Float>], obstacles: [Obstacle]) {
        let mirror: Float = variant.isMultiple(of: 2) ? 1 : -1
        let boxes = obstacles.map { Obstacle(position: [$0.position.x * mirror, $0.position.y, $0.position.z], size: $0.size) }
        var positions: [SIMD3<Float>] = []
        for target in targets {
            let base = SIMD3<Float>(target.x * mirror, max(0.35, kind.hitBox.y / 2 + 0.06), target.z)
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
        Stage(kind: .notification, timeLimit: 35,
              targets: [[0, 0.28, -2], [-2, 0.28, -6], [2, 0.28, -3.5], [0.5, 0.28, -9]],
              obstacles: [Obstacle(position: [-3, 0.6, -3], size: [1.6, 1.2, 1.6]),
                          Obstacle(position: [3.2, 0.4, -6], size: [1.8, 0.8, 1.8]),
                          Obstacle(position: [-4.5, 0.8, -10], size: [2, 1.6, 2])]),
        Stage(kind: .duvet, timeLimit: 40,
              targets: [[-1.8, 0.28, -2], [1.8, 0.28, -2], [-3, 0.28, -5], [3, 0.28, -5]],
              obstacles: []),
        Stage(kind: .loading, timeLimit: 45,
              targets: [[0, 0.28, -6], [-2.5, 0.28, -8], [2.5, 0.28, -9], [0.5, 0.28, -11]],
              obstacles: [Obstacle(position: [-4, 0.6, -5], size: [1.6, 1.2, 1.6])]),
        Stage(kind: .cable, timeLimit: 45,
              targets: [[-5, 0.28, -3], [5, 0.28, -3], [-4, 0.28, -8], [4, 0.28, -9]],
              obstacles: [Obstacle(position: [0, 0.6, -6], size: [2, 1.2, 1.5])]),
        Stage(kind: .mail, timeLimit: 50,
              targets: [[-2, 0.28, -5], [0, 0.28, -8], [2, 0.28, -5], [-4, 0.28, -10]],
              obstacles: [Obstacle(position: [-1.5, 0.5, -3], size: [1, 1, 1]),
                          Obstacle(position: [1.5, 0.5, -3], size: [1, 1, 1])]),
        Stage(kind: .calendar, timeLimit: 50,
              targets: [[-3, 0.28, -7], [3, 0.28, -7], [-5, 0.28, -11], [5, 0.28, -11]],
              obstacles: [Obstacle(position: [0, 0.8, -4], size: [5, 1.6, 1.5]),
                          Obstacle(position: [-4.5, 0.4, -5], size: [1.5, 0.8, 1.5])]),
        Stage(kind: .battery, timeLimit: 55,
              targets: [[0, 0.28, -2], [-4, 0.28, -4], [4, 0.28, -7], [0, 0.28, -12]],
              obstacles: [Obstacle(position: [2, 0.6, -4], size: [1.5, 1.2, 1.5])]),
        Stage(kind: .password, timeLimit: 55,
              targets: [[-5, 0.28, -2], [5, 0.28, -3], [-4, 0.28, -9], [4, 0.28, -10], [0, 0.28, -12]],
              obstacles: [Obstacle(position: [-2.5, 0.6, -5], size: [1.5, 1.2, 1.5]),
                          Obstacle(position: [2.5, 0.6, -6], size: [1.5, 1.2, 1.5])]),
        Stage(kind: .task, timeLimit: 60,
              targets: [[-5, 0.28, -10], [-2.5, 0.28, -11], [0, 0.28, -12], [2.5, 0.28, -11], [5, 0.28, -10]],
              obstacles: [Obstacle(position: [-1.8, 0.6, -6], size: [1.5, 1.2, 1.5]),
                          Obstacle(position: [1.8, 0.6, -6], size: [1.5, 1.2, 1.5])]),
        Stage(kind: .dragon, timeLimit: 60,
              targets: [[0, 0.28, -2], [-5, 0.28, -5], [5, 0.28, -6], [-4, 0.28, -11], [0, 0.28, -12], [4, 0.28, -11]],
              obstacles: [Obstacle(position: [-2, 0.8, -4], size: [1.5, 1.6, 1.5]),
                          Obstacle(position: [2, 0.8, -7], size: [1.5, 1.6, 1.5]),
                          Obstacle(position: [0, 0.6, -9], size: [2, 1.2, 1.5])])
    ]
}
