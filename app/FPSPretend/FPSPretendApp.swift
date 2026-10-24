import SwiftUI

@main
struct FPSPretendApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.light) }
    }
}

private struct RootView: View {
    private enum Sheet: String, Identifiable { case settings, stages, collection; var id: String { rawValue } }
    @State private var state = GameState()
    @State private var world: GameWorld?
    @State private var sound = ShotSound()
    @State private var sheet: Sheet?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 250 / 255, green: 247 / 255, blue: 238 / 255).ignoresSafeArea()
            switch state.phase {
            case .title:
                TitleView(progress: state.progress, onStart: start, onSettings: { sheet = .settings },
                          onStages: { sheet = .stages }, onCollection: { sheet = .collection })
            case .game, .resolution:
                if let world { GameView(state: state, world: world, onSettings: { sheet = .settings }, onTitle: state.returnToTitle) }
            case .result: ResultView(state: state, onContinue: continueGame, onRetry: retryGame, onTitle: state.returnToTitle)
            }
        }
        .onChange(of: state.phase) { _, phase in
            if phase == .result || phase == .title { world?.stop(); world = nil }
        }
        .sheet(item: $sheet) { selected in
            switch selected {
            case .settings:
                SettingsView(sound: sound, onTitle: state.phase == .title ? nil : {
                    state.returnToTitle()
                    sheet = nil
                })
            case .stages: StageSelectView(progress: state.progress) { index in
                sheet = nil
                if state.start(stageIndex: index) { runStage() }
            }
            case .collection: CollectionView(progress: state.progress, isActive: scenePhase == .active)
            }
        }
        .onChange(of: sheet) { _, selected in
            if selected != nil { state.pause() } else { state.resume() }
            world?.setActive(selected == nil && scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            world?.setActive(phase == .active && sheet == nil)
            if phase != .active { sound.stop() }
        }
        .onDisappear { world?.stop() }
    }

    private func start() {
        state.start()
        runStage()
    }

    private func continueGame() {
        guard state.phase == .result else { return }
        state.continueFromResult()
        runStage()
    }

    private func retryGame() {
        guard state.phase == .result else { return }
        state.retry()
        runStage()
    }

    private func runStage() {
        world?.stop()
        let next = GameWorld(state: state, sound: sound)
        world = next
        next.start()
    }
}
