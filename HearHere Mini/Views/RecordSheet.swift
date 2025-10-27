
import SwiftUI
import AVFoundation

struct RecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = RecordingManager()

    let onComplete: (RecordingResult?) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Record a short note (≤ 30s)").font(.headline)
            Text(timeString(rec.elapsed)).font(.system(.title, design: .monospaced))

            switch rec.permission {
            case .undetermined:
                Button("Allow Microphone") {
                    Task { _ = await rec.requestPermission() }
                }
                .buttonStyle(.borderedProminent)

            case .denied:
                VStack(spacing: 12) {
                    Text("Microphone is denied. Enable it in Settings.")
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

            case .granted:
                if rec.isRecording {
                    Button {
                        _ = rec.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.circle.fill").font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        _ = rec.start(maxDuration: 30)
                    } label: {
                        Label("Record", systemImage: "record.circle.fill").font(.title2)
                    }
                    .buttonStyle(.borderedProminent)

                    if rec.elapsed > 0 {
                        HStack {
                            Button("Discard") {
                                rec.discard()
                                onComplete(nil)
                                dismiss()
                            }
                            Button("Use Recording") {
                                let result = rec.stop()
                                onComplete(result)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear { rec.refreshPermission() }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.down))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
