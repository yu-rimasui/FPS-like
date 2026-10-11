import SwiftUI
import RealityKit

struct TitleView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle().fill(Color(hex: 0x82906a)).frame(width: 8, height: 8)
                Eyebrow(text: "ALL CLEAR. ALL YOURS.")
                Spacer()
            }.padding(.top, 28)
            Spacer(minLength: 40)
            VStack(spacing: 0) {
                Text("FPS").font(AppFonts.pixel(80)).tracking(4)
                (Text("ごっこ") + Text(".").foregroundColor(AppColors.coral))
                    .font(AppFonts.pixel(48)).tracking(5.7)
                Rectangle().fill(AppColors.coral).frame(width: 32, height: 3).padding(.top, 28)
                Text("「弟が全部倒しといたから。」").font(AppFonts.pixel(14)).padding(.top, 24)
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                PixelSpark().fill(AppColors.coral).frame(width: 24, height: 24).offset(x: -32, y: -32)
            }
            HStack(spacing: 8) {
                ForEach([0x9aa886, 0xc3cfb3, 0xe0e5d2], id: \.self) { hex in
                    Rectangle().fill(Color(hex: UInt32(hex))).frame(width: 8, height: 8)
                }
            }.padding(.top, 56).accessibilityHidden(true)
            Spacer(minLength: 40)
            VStack(spacing: 16) {
                Button(action: onStart) { Text("▶  START").font(AppFonts.pixel(18)) }
                    .buttonStyle(PixelButtonStyle(fill: AppColors.sage)).accessibilityIdentifier("startButton")
                Button {} label: { Text("✚  設定").foregroundStyle(AppColors.muted) }
                    .buttonStyle(PixelButtonStyle()).disabled(true)
                    .accessibilityHint("MVPでは利用できません")
            }
            Text("NO ENEMIES. NO WORRIES.").font(.system(size: 10, design: .monospaced))
                .tracking(1.5).foregroundStyle(AppColors.muted).padding(.top, 28)
        }
        .padding(.horizontal, 32).padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppColors.ink).background(AppColors.paper)
    }
}

struct ResultView: View {
    let state: GameState
    let onReplay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: "GOOD JOB, PLAYER 1.")
                Spacer()
                PixelSpark().fill(Color(hex: 0x839471)).frame(width: 20, height: 20)
            }.padding(.top, 28)
            (Text("Mission\nComplete") + Text("!").foregroundColor(AppColors.coral))
                .font(AppFonts.pixel(34)).lineSpacing(3).padding(.top, 28)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                GameDialog(speaker: "弟", message: "どうだった？")
                GameDialog(speaker: "姉", message: "FPSやった！", sister: true)
                GameDialog(speaker: "弟", message: "敵全部倒したの俺だけどね。")
            }.padding(.top, 28)
            GamePanel(fill: Color(hex: 0xeef0e3)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("スコア").font(AppFonts.pixel(12)); Spacer(); Eyebrow(text: "SCORE") }
                    Text(String(format: "%06d", state.score)).font(AppFonts.pixel(48)).tracking(2.8)
                        .accessibilityIdentifier("resultScore")
                }
            }.padding(.top, 32)
            HStack(spacing: 12) {
                StatCard(title: "命中率", value: "\(state.accuracy)", suffix: "%", identifier: "resultAccuracy")
                StatCard(title: "コンボ", value: String(format: "%02d", state.maxCombo), suffix: "MAX", identifier: "resultCombo")
            }.padding(.top, 12)
            Spacer(minLength: 24)
            Button("▶  Play Again", action: onReplay)
                .buttonStyle(PixelButtonStyle(fill: AppColors.sage)).accessibilityIdentifier("replayButton")
        }
        .padding(.horizontal, 28).padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppColors.ink).background(AppColors.paper)
    }
}

struct GameDialog: View {
    let speaker: String
    let message: String
    var sister = false

    private var avatar: some View {
        Text(speaker).font(AppFonts.pixel(12)).frame(width: 32, height: 32)
            .background(sister ? AppColors.coral : AppColors.sage)
            .overlay(Rectangle().strokeBorder(AppColors.ink))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if sister { Spacer(minLength: 0) } else { avatar }
            Text(message).font(AppFonts.pixel(message.count > 12 ? 12 : 13))
                .padding(.horizontal, 16).padding(.vertical, 13)
                .background(sister ? Color(hex: 0xf6e4d7) : AppColors.paper)
                .overlay(Rectangle().strokeBorder(AppColors.ink))
            if sister { avatar } else { Spacer(minLength: 0) }
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(speaker)「\(message)」")
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
            if state.hitFeedback {
                Text("HIT! +100").font(AppFonts.pixel(18)).padding(8).background(AppColors.paper)
                    .offset(y: -48).allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    hudStat("SCORE", value: String(format: "%06d", state.score), identifier: "scoreLabel")
                    hudStat("TIME", value: String(format: "%02d:%02d", state.remainingTime / 60, state.remainingTime % 60), identifier: "timerLabel")
                        .frame(width: 112)
                }
                HStack {
                    Text("■ 0 ALIVE").font(.system(size: 10, design: .monospaced)).tracking(1)
                        .padding(6).background(AppColors.paper.opacity(0.9))
                    Spacer()
                    Button {} label: { Text("武器変更 ⇄").font(AppFonts.pixel(11)) }
                        .buttonStyle(PixelButtonStyle(shadow: false)).frame(width: 104).disabled(true)
                }.padding(.top, 18)
                Spacer()
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
                    }.frame(width: 104)
                }
                HStack {
                    Text("弟が片付けた訓練場").font(AppFonts.pixel(11))
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

private struct WorldView: UIViewRepresentable {
    let world: GameWorld
    func makeUIView(context: Context) -> ARView { world.view }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
