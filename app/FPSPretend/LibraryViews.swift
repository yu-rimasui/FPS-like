import SwiftUI

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
                            Text(hasSeen ? motion.collectionDetails.description : "？？？")
                                .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                        }
                    }.accessibilityIdentifier("collectionEnemy\(index + 1)")
                }
                Text("出会った人形の記録は、途中でやめても残ります。")
                    .font(AppFonts.pixel(12)).foregroundStyle(AppColors.muted)
            }.padding(24)
        }.background(AppColors.paper).foregroundStyle(AppColors.ink)
    }
}
