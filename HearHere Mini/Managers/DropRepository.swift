import Foundation
import CoreLocation

protocol DropRepository {
    func loadAll() throws -> [AudioDrop]
    func saveAll(_ drops: [AudioDrop]) throws
    func add(_ drop: AudioDrop) throws
    func nearby(from drops: [AudioDrop], center: CLLocationCoordinate2D, within meters: CLLocationDistance) -> [AudioDrop]
}

// MARK: - Local JSON-backed repository
struct LocalDropRepository: DropRepository {
    private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appendingPathComponent("drops.json")) {
        self.fileURL = fileURL
    }

    func loadAll() throws -> [AudioDrop] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([AudioDrop].self, from: data)
    }

    func saveAll(_ drops: [AudioDrop]) throws {
        let data = try JSONEncoder().encode(drops)
        try data.write(to: fileURL, options: .atomic)
    }

    func add(_ drop: AudioDrop) throws {
        var existing = try loadAll()
        existing.append(drop)
        try saveAll(existing)
    }

    func nearby(from drops: [AudioDrop], center: CLLocationCoordinate2D, within meters: CLLocationDistance) -> [AudioDrop] {
        drops.sorted { a, b in
            a.distance(to: center) < b.distance(to: center)
        }
        .filter { $0.distance(to: center) <= meters }
    }
}

private extension AudioDrop {
    func distance(to c: CLLocationCoordinate2D) -> CLLocationDistance {
        let a = CLLocation(latitude: latitude, longitude: longitude)
        let b = CLLocation(latitude: c.latitude, longitude: c.longitude)
        return a.distance(from: b)
    }
}

private extension URL {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
