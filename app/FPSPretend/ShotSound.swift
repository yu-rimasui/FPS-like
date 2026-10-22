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
    private(set) var milestonePlayer: AVAudioPlayer?
    private(set) var resolutionPlayer: AVAudioPlayer?
    private(set) var lastVariants: [ShotStyle: Int] = [:]
    private(set) var lastHitVariants: [HitMaterial: Int] = [:]
    private var shotVoices: [AVAudioPlayer] = []
    private var hitVoices: [AVAudioPlayer] = []
    var activeVoiceCount: Int { players.values.filter(\.isPlaying).count }
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
        let shots = ShotStyle.allCases.flatMap { style in (0..<3).map { "shot_\(style.rawValue)_\($0)" } }
        let hits = HitMaterial.allCases.flatMap { material in
            ["hit_\(material.rawValue)", "hit_\(material.rawValue)_1", "hit_\(material.rawValue)_2"]
        }
        let names = shots + hits + ["milestone", "resolve", "finale"]
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
        guard volume > 0 else { stop(); return }
        let style = ShotStyle(rawValue: defaults.string(forKey: "shotSoundStyle") ?? "pop") ?? .pop
        var rng = SystemRandomNumberGenerator()
        let variant = Self.nextVariant(after: lastVariants[style], using: &rng)
        lastVariants[style] = variant
        player = players["shot_\(style.rawValue)_\(variant)"]
        keepTail(player, voices: &shotVoices)
        restart(player, gain: resolutionPlayer?.isPlaying == true ? 0.18 : 0.24)
    }

    func playHit(_ material: HitMaterial) {
        guard volume > 0 else { stop(); return }
        var rng = SystemRandomNumberGenerator()
        let variant = Self.nextVariant(after: lastHitVariants[material], using: &rng)
        lastHitVariants[material] = variant
        hitPlayer = players["hit_\(material.rawValue)" + (variant == 0 ? "" : "_\(variant)")]
        keepTail(hitPlayer, voices: &hitVoices)
        restart(hitPlayer, gain: 0.2)
    }

    func playMilestone() {
        milestonePlayer = players["milestone"]
        restart(milestonePlayer, gain: 0.18)
    }

    private func keepTail(_ audio: AVAudioPlayer?, voices: inout [AVAudioPlayer]) {
        voices.removeAll { !$0.isPlaying || $0 === audio }
        // Two quiet tails per role avoid cutting every tap and cap burst loudness.
        while voices.count >= 2 { voices.removeFirst().pause() }
        if let audio { voices.append(audio) }
    }

    func playResolution(final: Bool) {
        resolutionPlayer?.pause()
        resolutionPlayer = players[final ? "finale" : "resolve"]
        restart(resolutionPlayer, gain: 0.35)
    }

    private func restart(_ audio: AVAudioPlayer?, gain: Float) {
        guard let audio else { return }
        // Pause keeps the preloaded buffer ready for the next use.
        if audio.isPlaying { audio.pause() }
        audio.currentTime = 0
        guard volume > 0 else { stop(); return }
        audio.volume = volume * gain
        audio.play()
    }

    func stop() {
        let voices = shotVoices + hitVoices + [milestonePlayer, resolutionPlayer].compactMap { $0 }
        for audio in voices where audio.isPlaying { audio.pause(); audio.currentTime = 0 }
        shotVoices.removeAll()
        hitVoices.removeAll()
    }
}
