

import Foundation
import AVFoundation
import Combine

enum MicPermission { case undetermined, denied, granted }

struct RecordingResult {
    let fileURL: URL
    let duration: TimeInterval
}

@MainActor
final class RecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var permission: MicPermission = .undetermined

    private var recorder: AVAudioRecorder?
    private var ticker: AnyCancellable?

    // MARK: - Permission

    func refreshPermission() {
        permission = Self.currentPermission()
    }

    static func currentPermission() -> MicPermission {
        if #available(iOS 17.0, *) {
            // ⬅️ use the instance property on `.shared`
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined: return .undetermined
            case .denied:       return .denied
            case .granted:      return .granted
            @unknown default:   return .undetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .undetermined: return .undetermined
            case .denied:       return .denied
            case .granted:      return .granted
            @unknown default:   return .undetermined
            }
        }
    }
    func requestPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { cont in
                // ⬅️ iOS 17: static request API
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permission = Self.currentPermission()
                        cont.resume(returning: granted)
                    }
                }
            }
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permission = Self.currentPermission()
                        cont.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Recording

    func start(maxDuration: TimeInterval = 30) -> Bool {
        guard permission == .granted else { return false }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session error:", error.localizedDescription)
            return false
        }

        let filename = "drop-\(ISO8601DateFormatter().string(from: Date())).m4a"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            print("AVAudioRecorder init error:", error.localizedDescription)
            return false
        }

        recorder?.isMeteringEnabled = true
        recorder?.record(forDuration: maxDuration)

        isRecording = true
        elapsed = 0

        // Main-safe elapsed updates using Combine timer
        ticker?.cancel()
        ticker = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let r = self.recorder, r.isRecording {
                    self.elapsed = r.currentTime
                    if self.elapsed >= maxDuration {
                        _ = self.stop()
                    }
                } else {
                    self.ticker?.cancel()
                }
            }

        return true
    }

    func stop() -> RecordingResult? {
        guard let recorder else { return nil }
        recorder.stop()
        ticker?.cancel()
        isRecording = false
        let result = RecordingResult(fileURL: recorder.url, duration: recorder.currentTime)
        self.recorder = nil
        return result
    }

    func discard() {
        if let url = recorder?.url { try? FileManager.default.removeItem(at: url) }
        ticker?.cancel()
        recorder?.stop()
        recorder = nil
        isRecording = false
        elapsed = 0
    }
}
