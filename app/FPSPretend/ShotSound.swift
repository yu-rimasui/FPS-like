import AVFAudio
import OSLog

enum ShotStyle: String, CaseIterable, Identifiable {
    case pop, toy, soft
    var id: String { rawValue }
    var label: String {
        switch self { case .pop: return "ポップ"; case .toy: return "おもちゃ"; case .soft: return "やわらか" }
    }
}

enum HitMaterial: String, CaseIterable { case gel, cloth, digital, rubber, paper, metal }

@MainActor
final class ShotSound {
    private let defaults: UserDefaults
    private(set) var player: AVAudioPlayer?
    private(set) var hitPlayer: AVAudioPlayer?
    private(set) var resolutionPlayer: AVAudioPlayer?
    private(set) var lastVariants: [ShotStyle: Int] = [:]
    private(set) var loadFailures: [String] = []
    private var players: [String: AVAudioPlayer] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            Logger(subsystem: "dev.tryfps.FPSPretend", category: "audio")
                .error("音声の初期化に失敗: \(error.localizedDescription, privacy: .public)")
        }
        let names = ShotStyle.allCases.flatMap { style in (0..<3).map { "shot_\(style.rawValue)_\($0)" } }
            + HitMaterial.allCases.map { "hit_\($0.rawValue)" } + ["resolve", "finale"]
        for name in names {
            do {
                guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let audio = try AVAudioPlayer(contentsOf: url)
                audio.prepareToPlay()
                players[name] = audio
            } catch {
                loadFailures.append(name)
                Logger(subsystem: "dev.tryfps.FPSPretend", category: "audio").error("同梱SEの読込み失敗: \(name, privacy: .public)")
            }
        }
    }

    private var volume: Float {
        let enabled = defaults.object(forKey: "shotSoundEnabled") as? Bool ?? true
        let storedVolume = defaults.object(forKey: "shotSoundVolume") as? Double ?? 0.65
        let volume = storedVolume.isFinite ? min(1, max(0, storedVolume)) : 0.65
        return enabled ? Float(volume) : 0
    }

    static func nextVariant<R: RandomNumberGenerator>(after previous: Int?, using rng: inout R) -> Int {
        var next = Int.random(in: 0..<(previous == nil ? 3 : 2), using: &rng)
        if let previous, next >= previous { next += 1 }
        return next
    }

    func play() {
        player?.pause()
        guard volume > 0 else { return }
        let style = ShotStyle(rawValue: defaults.string(forKey: "shotSoundStyle") ?? "pop") ?? .pop
        var rng = SystemRandomNumberGenerator()
        let variant = Self.nextVariant(after: lastVariants[style], using: &rng)
        lastVariants[style] = variant
        player = players["shot_\(style.rawValue)_\(variant)"]
        restart(player, gain: resolutionPlayer?.isPlaying == true ? 0.24 : 0.45)
    }

    func playHit(_ material: HitMaterial) {
        hitPlayer?.pause()
        hitPlayer = players["hit_\(material.rawValue)"]
        restart(hitPlayer, gain: 0.3)
    }

    func playResolution(final: Bool) {
        resolutionPlayer?.pause()
        resolutionPlayer = players[final ? "finale" : "resolve"]
        restart(resolutionPlayer, gain: 0.5)
    }

    private func restart(_ audio: AVAudioPlayer?, gain: Float) {
        guard let audio else { return }
        // Pause keeps the buffers prepared; each role has at most one playing voice.
        audio.pause()
        audio.currentTime = 0
        guard volume > 0 else { return }
        audio.volume = volume * gain
        audio.play()
    }

    func stop() { for audio in players.values { audio.pause(); audio.currentTime = 0 } }
}
