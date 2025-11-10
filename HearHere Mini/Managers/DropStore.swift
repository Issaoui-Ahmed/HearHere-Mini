import Foundation
import CoreLocation
import Combine

@MainActor
final class DropStore: ObservableObject {
    @Published private(set) var drops: [AudioDrop] = []

    private let repository: DropRepository
    private let cloudRepository: CloudKitDropRepository?

    // Default to local repo; inject a different one (e.g., CloudKit) later.
    init(
        repository: DropRepository = LocalDropRepository(),
        cloudRepository: CloudKitDropRepository? = CloudKitDropRepository()
    ) {
        self.repository = repository
        self.cloudRepository = cloudRepository
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
        Task { await uploadToCloud(drop, fileURL: resultURL) }
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
        Task { await refreshFromCloud() }
    }

    private func persist() {
        do {
            try repository.saveAll(drops)
        } catch {
            print("DropStore save error:", error.localizedDescription)
        }
    }

    private func uploadToCloud(_ drop: AudioDrop, fileURL: URL) async {
        guard let cloudRepository else { return }
        do {
            try await cloudRepository.save(drop, audioFileURL: fileURL)
        } catch {
            print("DropStore cloud save error:", error.localizedDescription)
        }
    }

    private func refreshFromCloud() async {
        guard let cloudRepository else { return }
        do {
            let remoteDrops = try await cloudRepository.fetchAll()
            mergeRemoteDrops(remoteDrops)
        } catch {
            print("DropStore cloud fetch error:", error.localizedDescription)
        }
    }

    private func mergeRemoteDrops(_ remoteDrops: [AudioDrop]) {
        var combined: [UUID: AudioDrop] = [:]

        for drop in drops {
            combined[drop.id] = drop
        }

        for drop in remoteDrops {
            combined[drop.id] = drop
        }

        let merged = combined.values.sorted { $0.createdAt < $1.createdAt }
        if merged != drops {
            drops = merged
            persist()
        }
    }
}
