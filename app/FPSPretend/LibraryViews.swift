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
                    Text("イラッと解決図鑑").font(AppFonts.pixel(21)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("閉じる") { dismiss() }.frame(minWidth: 60, minHeight: 44)
                        .accessibilityIdentifier("closeLibraryButton")
                }
                Text("出会い \(progress.seen.count)/10 ・ 発見したオチ \(progress.endings.count)/30")
                    .font(AppFonts.pixel(13)).accessibilityIdentifier("collectionProgress")
                ForEach(Stage.all.indices, id: \.self) { index in
                    GamePanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(progress.seen.contains(index) ? Stage.all[index].name : "\(index + 1). まだ出会っていません")
                                .font(AppFonts.pixel(16)).accessibilityAddTraits(.isHeader)
                            ForEach(0..<3) { ending in
                                Text(progress.endings.contains("\(index):\(ending)") ? "「\(Stage.all[index].kind.details.endings[ending])」" : "？？？")
                                    .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                            }
                        }
                    }.accessibilityIdentifier("collectionEnemy\(index + 1)")
                }
                Text("再プレイで別のオチが見つかります。中断しても発見は残ります。")
                    .font(AppFonts.pixel(12)).foregroundStyle(AppColors.muted)
            }.padding(24)
        }.background(AppColors.paper).foregroundStyle(AppColors.ink)
    }
}
