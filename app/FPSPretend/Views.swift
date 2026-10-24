import SwiftUI
import RealityKit

struct TitleView: View {
    let progress: ProgressStore
    let onStart: () -> Void
    let onSettings: () -> Void
    let onStages: () -> Void
    let onCollection: () -> Void

    var body: some View {
        ScrollView { VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle().fill(Color(hex: 0x82906a)).frame(width: 8, height: 8)
                Eyebrow(text: "ALL CLEAR. ALL YOURS.")
                Spacer()
            }.padding(.top, 28)
            Color.clear.frame(height: 36)
            VStack(spacing: 0) {
                Text("FPS").font(AppFonts.pixel(64)).tracking(4)
                (Text("ごっこ") + Text(".").foregroundColor(AppColors.coral))
                    .font(AppFonts.pixel(40)).tracking(5.7)
                Rectangle().fill(AppColors.coral).frame(width: 32, height: 3).padding(.top, 28)
                Text("戦わなくていいFPS。").font(AppFonts.pixel(14)).padding(.top, 24)
                Text("動く人形を、気軽にねらおう。").font(AppFonts.pixel(13)).padding(.top, 12)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                PixelSpark().fill(AppColors.coral).frame(width: 24, height: 24).offset(x: -32, y: -32)
            }
            HStack(spacing: 8) {
                ForEach([0x9aa886, 0xc3cfb3, 0xe0e5d2], id: \.self) { hex in
                    Rectangle().fill(Color(hex: UInt32(hex))).frame(width: 8, height: 8)
                }
            }.padding(.top, 24).accessibilityHidden(true)
            Color.clear.frame(height: 32)
            VStack(spacing: 16) {
                Text("全\(Stage.all.count)ステージ / クリア \(progress.cleared.count)/\(Stage.all.count)")
                    .font(AppFonts.pixel(12)).foregroundStyle(AppColors.muted).accessibilityIdentifier("savedProgress")
                Button(action: onStart) { Text("▶  START · STAGE \(progress.currentStage + 1)").font(AppFonts.pixel(16)) }
                    .buttonStyle(PixelButtonStyle(fill: AppColors.sage)).accessibilityIdentifier("startButton")
                Button("ステージ選択", action: onStages).buttonStyle(PixelButtonStyle())
                    .accessibilityIdentifier("stageSelectButton")
                Button("人形の図鑑", action: onCollection).buttonStyle(PixelButtonStyle())
                    .accessibilityIdentifier("collectionButton")
                Button("✚  設定", action: onSettings)
                    .buttonStyle(PixelButtonStyle()).accessibilityIdentifier("settingsButton")
            }
            Text("NO ENEMIES. NO WORRIES.").font(.system(size: 10, design: .monospaced))
                .tracking(1.5).foregroundStyle(AppColors.muted).padding(.top, 28)
        }
        .padding(.horizontal, 32).padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppColors.ink).background(AppColors.paper)
    }
}

struct ResultView: View {
    let state: GameState
    let onContinue: () -> Void
    let onRetry: () -> Void
    let onTitle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "STAGE \(state.stageIndex + 1) / \(Stage.all.count)")
                    .accessibilityIdentifier("resultStage")
                Spacer()
                PixelSpark().fill(Color(hex: 0x839471)).frame(width: 20, height: 20)
            }.padding(.top, 28)
            Text(state.isCleared ? (state.isFinalStage ? "全\(Stage.all.count)ステージ\nクリア！" : "Stage\nClear!") : "タイムアップ")
                .font(AppFonts.pixel(34)).lineSpacing(3).padding(.top, 28)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("resultStatus")
            Text(state.stage.goal).font(AppFonts.pixel(12)).padding(.top, 16)
            Text("消えた人形 \(state.resolvedCount)/\(state.stage.requiredTargets) ・ 命中 \(state.hitCount)")
                .font(AppFonts.pixel(12)).padding(.top, 8).accessibilityIdentifier("resultProgress")
            if state.isCleared {
                Text("「\(state.ending)」").font(AppFonts.pixel(18)).multilineTextAlignment(.leading)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.sage).padding(.top, 16).accessibilityIdentifier("resultEnding")
                Text(state.isFinalStage ? "全\(Stage.all.count)ステージの人形を消しました！" : "次のステージが解放されました。")
                    .font(AppFonts.pixel(12)).padding(.top, 8)
            }
            GamePanel(fill: Color(hex: 0xeef0e3)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("スコア").font(AppFonts.pixel(12)); Spacer(); Eyebrow(text: "SCORE") }
                    Text(String(format: "%06d", state.score)).font(AppFonts.pixel(36)).tracking(2.8)
                        .accessibilityIdentifier("resultScore")
                }
            }.padding(.top, 20)
            HStack(spacing: 12) {
                StatCard(title: "命中率", value: "\(state.accuracy)", suffix: "%", identifier: "resultAccuracy")
                StatCard(title: "コンボ", value: String(format: "%02d", state.maxCombo), suffix: "MAX", identifier: "resultCombo")
            }.padding(.top, 12)
            Spacer(minLength: 24)
            Button(state.isCleared ? (state.isFinalStage ? "▶  ステージ1からもう一度" : "▶  次のステージへ") : "▶  もう一度", action: onContinue)
                .buttonStyle(PixelButtonStyle(fill: AppColors.sage))
                .accessibilityIdentifier(state.isCleared && !state.isFinalStage ? "nextStageButton" : "replayButton")
            if state.isCleared {
                Button("↻ 同じステージでもう一度", action: onRetry).buttonStyle(PixelButtonStyle())
                    .padding(.top, 12).accessibilityIdentifier("retryStageButton")
            }
            Button("タイトルへ", action: onTitle).buttonStyle(PixelButtonStyle())
                .padding(.top, 12).accessibilityIdentifier("titleButton")
        }
        .padding(.horizontal, 28).padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppColors.ink).background(AppColors.paper)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let suffix: String
    let identifier: String
    var body: some View {
        GamePanel(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(AppFonts.pixel(12))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value).font(AppFonts.pixel(27))
                    Text(suffix).font(AppFonts.pixel(suffix == "%" ? 14 : 10))
                }.accessibilityElement(children: .combine).accessibilityIdentifier(identifier)
            }
        }
    }
}

struct GameView: View {
    let state: GameState
    let world: GameWorld
    let onSettings: () -> Void
    let onTitle: () -> Void
    @State private var lastAim = CGSize.zero
    @GestureState private var moving = false
    @State private var stick = CGSize.zero

    var body: some View {
        ZStack {
            WorldView(world: world)
            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        world.look(delta: CGSize(width: value.translation.width - lastAim.width,
                                                 height: value.translation.height - lastAim.height))
                        lastAim = value.translation
                    }.onEnded { _ in lastAim = .zero })
                .accessibilityLabel("視点操作").accessibilityIdentifier("aimArea")
                .accessibilityHint("ドラッグして上下左右を見ます")
            Reticle().allowsHitTesting(false)
            if state.hitFeedback || state.phase == .resolution {
                Text(state.message).font(AppFonts.pixel(15)).multilineTextAlignment(.center)
                    .padding(12).frame(maxWidth: 290).background(AppColors.paper)
                    .offset(y: -48).allowsHitTesting(false).accessibilityIdentifier("reactionMessage")
            }
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("STAGE \(state.stageIndex + 1)/\(Stage.all.count)  \(state.stage.name)")
                            .font(AppFonts.pixel(12)).accessibilityIdentifier("stageLabel")
                        Spacer()
                        Button(action: onSettings) { Image(systemName: "gearshape").frame(width: 44) }
                            .buttonStyle(PixelButtonStyle(shadow: false)).frame(width: 48)
                            .accessibilityLabel("設定").accessibilityIdentifier("settingsButton")
                    }
                    Text(state.stage.goal).font(AppFonts.pixel(11)).accessibilityIdentifier("stageGoal")
                    Text(state.stage.kind.instruction).font(AppFonts.pixel(11))
                        .accessibilityIdentifier("stageInstruction")
                    Text(state.progressText).font(AppFonts.pixel(11)).accessibilityIdentifier("stageProgress")
                    ProgressView(value: state.progressFraction).tint(Color(hex: 0x758567))
                        .accessibilityLabel("人形の命中進捗").accessibilityIdentifier("workProgressBar")
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.paper).overlay(Rectangle().strokeBorder(AppColors.ink))
                    .padding(.bottom, 12)
                HStack(spacing: 12) {
                    hudStat("SCORE", value: String(format: "%06d", state.score), identifier: "scoreLabel")
                    hudStat("TIME", value: String(format: "%02d:%02d", state.remainingTime / 60, state.remainingTime % 60), identifier: "timerLabel")
                        .frame(width: 112)
                }
                HStack {
                    Text("NO DAMAGE").font(.system(size: 10, design: .monospaced)).tracking(1)
                        .padding(6).background(AppColors.paper.opacity(0.9))
                    Spacer()
                    Button("タイトルへ", action: onTitle).font(AppFonts.pixel(11))
                        .buttonStyle(PixelButtonStyle(shadow: false)).frame(width: 104)
                        .accessibilityIdentifier("leaveStageButton")
                }.padding(.top, 18)
                Spacer()
                if state.phase == .resolution {
                    Button("✓ すっきり！ 結果へ", action: state.finishResolution)
                        .buttonStyle(PixelButtonStyle(fill: AppColors.sage))
                        .padding(.bottom, 12).accessibilityIdentifier("finishStageButton")
                }
                HStack(alignment: .bottom) {
                    joystick
                    Spacer()
                    VStack(spacing: 16) {
                        Button(action: world.reload) { Text("↻ リロード").font(AppFonts.pixel(11)) }
                            .buttonStyle(PixelButtonStyle()).accessibilityIdentifier("reloadButton")
                        Button(action: world.shoot) {
                            VStack(spacing: 8) {
                                Reticle()
                                Text("射撃").font(AppFonts.pixel(12))
                            }.frame(height: 104).frame(maxWidth: .infinity)
                        }.buttonStyle(PixelButtonStyle(fill: AppColors.coral))
                            .accessibilityIdentifier("fireButton")
                    }.frame(width: 104).disabled(state.phase != .game).opacity(state.phase == .game ? 1 : 0.45)
                }
                HStack {
                    Text("人形を気ままにねらおう").font(AppFonts.pixel(11))
                    Spacer()
                    Text("\(state.ammo) / ∞").font(.system(size: 12, design: .monospaced))
                        .accessibilityLabel("残弾 \(state.ammo)").accessibilityIdentifier("ammoLabel")
                }.padding(.top, 16).padding(.bottom, 10).padding(.horizontal, 8)
                    .background(AppColors.paper.opacity(0.94))
                    .overlay(alignment: .top) { Rectangle().fill(AppColors.line).frame(height: 1) }
                    .padding(.top, 26)
            }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 14)
        }.foregroundStyle(AppColors.ink)
            .onChange(of: moving) { _, active in
                if !active { world.move = .zero; stick = .zero }
            }
            .onDisappear { world.move = .zero; stick = .zero; lastAim = .zero }
    }

    private func hudStat(_ label: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: label)
            Text(value).font(AppFonts.pixel(24)).accessibilityIdentifier(identifier)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 8)
            .background(AppColors.paper).overlay(Rectangle().strokeBorder(AppColors.ink))
    }

    private var joystick: some View {
        VStack(spacing: 12) {
            Eyebrow(text: "MOVE").padding(4).background(AppColors.paper.opacity(0.9))
            ZStack {
                Color(hex: 0xdbe1cc)
                VStack { Text("▲"); Spacer(); Text("▼") }.padding(8)
                HStack { Text("◀"); Spacer(); Text("▶") }.padding(8)
                Rectangle().fill(AppColors.paper).frame(width: 48, height: 48)
                    .overlay(Rectangle().strokeBorder(Color(hex: 0x687957), lineWidth: 2))
                    .overlay { Rectangle().fill(Color(hex: 0x839471)).frame(width: 8, height: 8) }
                    .offset(stick)
            }.font(.system(size: 12, design: .monospaced)).frame(width: 120, height: 120)
                .overlay(Rectangle().strokeBorder(Color(hex: 0xa3af93)))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($moving) { _, active, _ in active = true }
                    .onChanged { value in
                        let x = value.translation.width
                        let y = value.translation.height
                        let scale = max(30, hypot(x, y))
                        world.move = SIMD2(Float(x / scale), Float(-y / scale))
                        stick = CGSize(width: x / scale * 24, height: y / scale * 24)
                    })
                .accessibilityElement(children: .ignore).accessibilityLabel("移動")
                .accessibilityHint("上下左右にドラッグして移動します")
                .accessibilityIdentifier("moveControl")
        }
    }
}

struct SettingsView: View {
    let sound: ShotSound
    let onTitle: (() -> Void)?
    @AppStorage("shotSoundEnabled") private var enabled = true
    @AppStorage("shotSoundVolume") private var volume = 0.65
    @AppStorage("shotSoundStyle") private var style = ShotStyle.pop.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("設定").font(AppFonts.pixel(24)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("閉じる") { dismiss() }.buttonStyle(PixelButtonStyle())
                        .frame(width: 88).accessibilityIdentifier("closeSettingsButton")
                }
                if let onTitle {
                    Button("スタートに戻る", action: onTitle)
                        .buttonStyle(PixelButtonStyle())
                        .accessibilityIdentifier("returnToStartButton")
                }
                GamePanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("SE", isOn: $enabled).font(AppFonts.pixel(16))
                            .tint(Color(hex: 0x758567)).accessibilityIdentifier("shotSoundToggle")
                        Text("発砲・命中・節目・解決の音をまとめて調整します。")
                            .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
                        Divider()
                        HStack {
                            Text("音量")
                            Spacer()
                            Text("\(Int(volume * 100))%")
                                .accessibilityIdentifier("soundVolumeLabel")
                        }.font(AppFonts.pixel(14))
                        Slider(value: $volume, in: 0...1).frame(minHeight: 44)
                            .tint(Color(hex: 0x758567)).disabled(!enabled)
                            .accessibilityLabel("SEの音量").accessibilityIdentifier("soundVolumeSlider")
                        Text("発砲音のタイプ").font(AppFonts.pixel(14))
                        Picker("発砲音のタイプ", selection: $style) {
                            ForEach(ShotStyle.allCases) { Text($0.label).tag($0.rawValue) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("soundStylePicker")
                            .disabled(!enabled)
                        Button("音を試す", action: sound.play)
                            .buttonStyle(PixelButtonStyle(fill: AppColors.sage)).disabled(!enabled || volume == 0)
                            .opacity(enabled && volume > 0 ? 1 : 0.45)
                            .accessibilityIdentifier("previewSoundButton")
                    }
                }
                GamePanel {
                    Toggle("振動", isOn: $hapticsEnabled).font(AppFonts.pixel(16))
                        .tint(Color(hex: 0x758567)).accessibilityIdentifier("hapticsToggle")
                }
                Text("設定は自動で保存されます。端末の消音モードでは音は鳴りません。")
                    .font(AppFonts.pixel(13)).foregroundStyle(AppColors.muted)
            }.padding(24)
        }.background(AppColors.paper).foregroundStyle(AppColors.ink)
            .onChange(of: enabled) { _, _ in sound.stop() }
            .onChange(of: volume) { _, _ in sound.stop() }
            .onChange(of: style) { _, _ in sound.stop() }
            .onDisappear { sound.stop() }
    }
}

private struct WorldView: UIViewRepresentable {
    let world: GameWorld
    func makeUIView(context: Context) -> ARView { world.view }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
