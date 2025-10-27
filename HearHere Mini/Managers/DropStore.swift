import Foundation
import CoreLocation
import Combine

@MainActor
final class DropStore: ObservableObject {
    @Published private(set) var drops: [AudioDrop] = []

    private let repository: DropRepository

    // Default to local repo; inject a different one (e.g., CloudKit) later.
    init(repository: DropRepository = LocalDropRepository()) {
        self.repository = repository
        load()
    }

    func add(resultURL: URL, duration: TimeInterval, at coordinate: CLLocationCoordinate2D) {
        let drop = AudioDrop(
            id: UUID(),
            createdAt: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            durationSec: duration,
            filename: resultURL.lastPathComponent
        )
        drops.append(drop)
        persist()
    }

    func nearby(center: CLLocationCoordinate2D, within meters: CLLocationDistance) -> [AudioDrop] {
        repository.nearby(from: drops, center: center, within: meters)
    }

    // MARK: - Persistence
    private func load() {
        do {
            drops = try repository.loadAll()
        } catch {
            print("DropStore load error:", error.localizedDescription)
            drops = []
        }
    }

    private func persist() {
        do {
            try repository.saveAll(drops)
        } catch {
            print("DropStore save error:", error.localizedDescription)
        }
    }
}
