
import Foundation
import CoreLocation

struct AudioDrop: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var latitude: Double
    var longitude: Double
    var durationSec: Double
    /// Store just the filename for portability; we rebuild the full URL at runtime.
    var filename: String

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}
