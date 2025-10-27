import Foundation
import AVFoundation
import Combine

@MainActor
final class PlaybackManager: ObservableObject {
    private var player: AVAudioPlayer?

    func play(fileURL: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: fileURL)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Playback error:", error.localizedDescription)
        }
    }

    func stop() { player?.stop() }
}
