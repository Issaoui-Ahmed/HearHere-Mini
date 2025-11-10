
// ContentView.swift
import SwiftUI
import MapKit
import CoreLocation
import SwiftData

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var player = PlaybackManager()

    @Environment(\.modelContext) private var modelContext

    // Live collection of drops from SwiftData (and hence CloudKit)
    @Query(sort: \AudioDrop.createdAt, order: .reverse)
    private var drops: [AudioDrop]

    @State private var showRecorder = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedDrop: AudioDrop?

    private let nearbyRadius: CLLocationDistance = 500 // still available if you need it

    var body: some View {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(drops) { drop in
                        Annotation("", coordinate: drop.coordinate) {
                            Button {
                                guard let data = drop.audioData else {
                                    print("No audio data stored for this drop")
                                    return
                                }

                                selectedDrop = drop
                                player.play(data: data)
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .ignoresSafeArea()
            Button {
                showRecorder = true
            } label: {
                Label("Record", systemImage: "record.circle.fill")
                    .font(.title2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding(.bottom, 24)
        }
        .task { locationManager.requestAuthorization() }
        .sheet(isPresented: $showRecorder) {
            RecordSheet { result in
                guard let result else {
                    print("No result (user canceled or recording failed)")
                    return
                }

                guard let loc = locationManager.location?.coordinate else {
                    print("No location available yet")
                    return
                }

                do {
                    // Turn the recorded file into Data for SwiftData/CloudKit.
                    let data = try Data(contentsOf: result.fileURL)

                    let drop = AudioDrop(
                        latitude: loc.latitude,
                        longitude: loc.longitude,
                        durationSec: result.duration,
                        audioData: data
                    )
                    modelContext.insert(drop)

                    print("✅ Added drop at", loc)

                    // (Optional) Delete the temp file if you don’t need it anymore.
                    try? FileManager.default.removeItem(at: result.fileURL)
                } catch {
                    print("Failed to load audio data:", error)
                }
            }
            .presentationDetents([.height(260), .medium])
        }
        .overlay(alignment: .top) {
            if let drop = selectedDrop {
                Text("Playing drop • \(Int(drop.durationSec))s")
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 10)
            }
        }
    }
}
