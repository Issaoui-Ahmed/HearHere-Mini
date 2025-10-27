

import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var store = DropStore()
    @StateObject private var player = PlaybackManager()

    @State private var showRecorder = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedDrop: AudioDrop?

    // Choose how far to surface pins in the current viewport/user area
    private let nearbyRadius: CLLocationDistance = 500 // meters

    var body: some View {
        ZStack(alignment: .bottom) {
            if #available(iOS 17.0, *) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    // Render pins for all drops (simple)
                    ForEach(store.drops) { drop in
                        Annotation("", coordinate: drop.coordinate) {
                            Button {
                                selectedDrop = drop
                                if let url = urlFor(drop) {
                                    player.play(fileURL: url)
                                }
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .ignoresSafeArea()
            } else {
                // iOS 16 fallback map (no cameraPosition API)
                LegacyMapView()
            }

            // Floating Record button
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

                store.add(resultURL: result.fileURL, duration: result.duration, at: loc)
                print("✅ Added drop at", loc)
            }
            .presentationDetents([.height(260), .medium])
        }
        // Optional mini “now playing” banner
        .overlay(alignment: .top) {
            if let drop = selectedDrop {
                Text("Playing drop • \(Int(drop.durationSec))s")
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 10)
            }
        }
    }

    private func urlFor(_ drop: AudioDrop) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(drop.filename)
    }
}

private struct LegacyMapView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    var body: some View {
        Map(coordinateRegion: $region, showsUserLocation: true)
            .ignoresSafeArea()
    }
}
