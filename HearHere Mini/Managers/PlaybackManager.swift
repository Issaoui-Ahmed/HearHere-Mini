
// PlaybackManager.swift
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

    // NEW: play from in-memory Data (what SwiftData/CloudKit stores)
    func play(data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Playback error (data):", error.localizedDescription)
        }
    }

    func stop() { player?.stop() }
}
