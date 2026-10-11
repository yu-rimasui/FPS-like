import SwiftUI

@main
struct FPSPretendApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.light) }
    }
}

private struct RootView: View {
    @State private var state = GameState()
    @State private var world: GameWorld?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 250 / 255, green: 247 / 255, blue: 238 / 255).ignoresSafeArea()
            switch state.phase {
            case .title: TitleView(onStart: start)
            case .game:
                if let world { GameView(state: state, world: world) }
            case .result: ResultView(state: state, onReplay: start)
            }
        }
        .onChange(of: state.phase) { _, phase in
            if phase == .result { world?.stop(); world = nil }
        }
        .onChange(of: scenePhase) { _, phase in world?.setActive(phase == .active) }
        .onDisappear { world?.stop() }
    }

    private func start() {
        world?.stop()
        let next = GameWorld(state: state)
        world = next
        next.start()
    }
}
