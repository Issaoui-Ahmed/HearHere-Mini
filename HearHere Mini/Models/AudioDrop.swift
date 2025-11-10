

// AudioDrop.swift
import Foundation
import CoreLocation
import SwiftData

@Model
final class AudioDrop {
    // All have defaults or are optional
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var latitude: Double = 0
    var longitude: Double = 0
    var durationSec: Double = 0
    var audioData: Data? = nil   // optional

    init(
        latitude: Double,
        longitude: Double,
        durationSec: Double,
        audioData: Data
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.durationSec = durationSec
        self.audioData = audioData
    }

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}
