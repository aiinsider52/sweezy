import AVFoundation
import SwiftUI

/// Reads a text aloud in the app language with the system voice, for people who find long
/// explanations hard to read. Nothing leaves the device.
@MainActor
final class ReadAloud: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// The installed system voice for the app language, if there is one.
    static var voice: AVSpeechSynthesisVoice? {
        let code: String
        switch AppLanguage.current.rawValue {
        case "uk": code = "uk-UA"
        case "de": code = "de-DE"
        default: code = "en-US"
        }
        return AVSpeechSynthesisVoice(language: code)
    }

    static var isAvailable: Bool { voice != nil }

    func toggle(_ text: String) {
        if isSpeaking {
            stop()
        } else {
            speak(text)
        }
    }

    func speak(_ text: String) {
        guard let voice = Self.voice, !text.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

/// Small "Listen / Stop" capsule.
struct ReadAloudButton: View {
    let text: String
    @StateObject private var reader = ReadAloud()

    var body: some View {
        if ReadAloud.isAvailable {
            Button { reader.toggle(text) } label: {
                Label(
                    reader.isSpeaking ? "read_aloud.stop".localized : "read_aloud.listen".localized,
                    systemImage: reader.isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                )
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(reader.isSpeaking ? .black : JourneyVisual.primaryText)
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(reader.isSpeaking ? JourneyVisual.lime : JourneyVisual.pageBackground, in: Capsule())
                .overlay(Capsule().stroke(reader.isSpeaking ? Color.clear : JourneyVisual.softBorder, lineWidth: 1))
                .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("readAloud.toggle")
            .onDisappear { reader.stop() }
        }
    }
}
