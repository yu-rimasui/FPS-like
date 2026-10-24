import SwiftUI
import RealityKit
import SceneKit

struct StageSelectView: View {
    let progress: ProgressStore
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("ステージ選択").font(AppFonts.pixel(24)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("閉じる") { dismiss() }.frame(minWidth: 60, minHeight: 44)
                        .accessibilityIdentifier("closeLibraryButton")
                }
                Text("クリアすると次が開きます。解放済みのステージは何度でも遊べます。")
                    .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                ForEach(Stage.all.indices, id: \.self) { index in
                    Button { onSelect(index) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(index + 1). \(Stage.all[index].name)").font(AppFonts.pixel(15))
                            Text(progress.cleared.contains(index) ? "✓ 解決済み" : (index <= progress.unlockedStage ? Stage.all[index].goal : "前のステージで解放"))
                                .font(AppFonts.pixel(11)).foregroundStyle(AppColors.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 8)
                    }.buttonStyle(PixelButtonStyle(fill: progress.cleared.contains(index) ? AppColors.sage : AppColors.paper))
                        .disabled(index > progress.unlockedStage).opacity(index <= progress.unlockedStage ? 1 : 0.45)
                        .accessibilityIdentifier("selectStage\(index + 1)")
                }
            }.padding(24)
        }.background(AppColors.paper).foregroundStyle(AppColors.ink)
    }
}
struct CollectionView: View {
    let progress: ProgressStore
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("人形の図鑑").font(AppFonts.pixel(21)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("閉じる") { dismiss() }.frame(minWidth: 60, minHeight: 44)
                        .accessibilityIdentifier("closeLibraryButton")
                }
                Text("出会い \(progress.seenMotions.count)/\(EnemyMotion.collectionMotions.count)")
                    .font(AppFonts.pixel(13)).accessibilityIdentifier("collectionProgress")
                Text("動きの違う人形は全7種類。出会うと、その人形のちょっと変わった事情が読めます。")
                    .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                ForEach(EnemyMotion.collectionMotions.indices, id: \.self) { index in
                    let motion = EnemyMotion.collectionMotions[index]
                    let hasSeen = progress.seenMotions.contains(motion)
                    GamePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(hasSeen ? motion.collectionDetails.name : "\(index + 1). まだ出会っていません")
                                .font(AppFonts.pixel(16)).accessibilityAddTraits(.isHeader)
                            HStack(alignment: .top, spacing: 12) {
                                if hasSeen {
                                    DollMotionPreview(motion: motion, isPlaying: isActive && !reducedMotion)
                                        .frame(width: 112, height: 112)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(motion.collectionDetails.name)の動き")
                                        .accessibilityValue(isActive && !reducedMotion ? "再生中" : "停止中")
                                }
                                Text(hasSeen ? motion.collectionDetails.description : "？？？")
                                    .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }.accessibilityIdentifier("collectionEnemy\(index + 1)")
                }
                Text("出会った人形の記録は、途中でやめても残ります。")
                    .font(AppFonts.pixel(12)).foregroundStyle(AppColors.muted)
            }.padding(24)
        }.background(AppColors.paper).foregroundStyle(AppColors.ink)
    }
}

struct DollMotionPreview: View {
    let motion: EnemyMotion
    let isPlaying: Bool
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { timeline in
            SceneView(motion: motion, time: Float(timeline.date.timeIntervalSince(startedAt)), isPlaying: isPlaying)
        }
    }

    private struct SceneView: UIViewRepresentable {
        let motion: EnemyMotion
        let time: Float
        let isPlaying: Bool
        func makeCoordinator() -> DollMotionPreview.Coordinator { Coordinator(motion: motion) }
        func makeUIView(context: Context) -> SCNView { context.coordinator.view }
        func updateUIView(_ view: SCNView, context: Context) {
            context.coordinator.update(time: time)
            view.isPlaying = isPlaying
            view.rendersContinuously = isPlaying
        }
        static func dismantleUIView(_ view: SCNView, coordinator: DollMotionPreview.Coordinator) {
            view.isPlaying = false
            view.rendersContinuously = false
        }
    }

    @MainActor final class Coordinator {
        let view = SCNView(frame: .zero)
        let enemy: EnemyVisual
        private var parts: [(ModelEntity, SCNNode)] = []

        init(motion: EnemyMotion) {
            enemy = EnemyVisual(motion: motion, position: [0, motion.height, 0],
                                color: EnemyVisual.colors.randomElement()!, requiredHits: 5)
            view.backgroundColor = UIColor(AppColors.paper)
            view.clipsToBounds = true
            view.scene = SCNScene()
            view.autoenablesDefaultLighting = true
            view.rendersContinuously = true
            view.isPlaying = true
            view.preferredFramesPerSecond = 30
            let root = view.scene!.rootNode
            let doll = SCNNode()
            doll.name = "doll"
            root.addChildNode(doll)
            func addParts(_ entity: Entity) {
                if let part = entity as? ModelEntity, let model = part.model {
                    let size = model.mesh.bounds.extents
                    let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
                    let material = SCNMaterial()
                    material.lightingModel = .lambert
                    if let source = model.materials.first as? SimpleMaterial { material.diffuse.contents = source.color.tint }
                    if let source = model.materials.first as? UnlitMaterial {
                        material.diffuse.contents = source.color.tint
                        material.lightingModel = .constant
                    }
                    box.firstMaterial = material
                    let node = SCNNode(geometry: box)
                    doll.addChildNode(node)
                    parts.append((part, node))
                }
                for child in entity.children { addParts(child) }
            }
            addParts(enemy.entity)
            let floor = SCNNode(geometry: SCNBox(width: 5, height: 0.05, length: 5, chamferRadius: 0))
            floor.geometry!.firstMaterial!.diffuse.contents = UIColor(AppColors.sage)
            floor.position.y = -0.025
            root.addChildNode(floor)
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera!.fieldOfView = 45
            camera.simdPosition = motion == .flying ? [2.7, 3.2, 4.2] : [2.1, 2.3, 3.3]
            camera.look(at: SCNVector3(0, motion == .flying ? 1.4 : 0.65, 0))
            root.addChildNode(camera)
            view.pointOfView = camera
            update(time: 0)
        }

        func update(time: Float) {
            enemy.update(time: time, reducedMotion: false)
            enemy.entity.position.x = sin(time * enemy.motion.speed) * 0.4
            for (part, node) in parts { node.simdTransform = part.transformMatrix(relativeTo: nil) }
        }
    }
}
