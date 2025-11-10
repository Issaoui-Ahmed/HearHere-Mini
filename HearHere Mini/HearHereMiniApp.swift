

// HearHereMiniApp.swift
import SwiftUI
import SwiftData

@main
struct HearHereMiniApp: App {

    let modelContainer: ModelContainer = {
        let schema = Schema([AudioDrop.self])

        // Use CloudKit for this schema
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic   // uses the container from your entitlements
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("❌ Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
