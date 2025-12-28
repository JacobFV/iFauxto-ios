import SwiftUI
import SwiftData

@main
struct iFauxtoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Folder.self,
            FolderAsset.self,
            AssetTag.self,
            UserPreferences.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    ensureUserPreferencesExist()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func ensureUserPreferencesExist() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<UserPreferences>()

        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let preferences = UserPreferences()
                context.insert(preferences)
                try context.save()
            }
        } catch {
            print("Failed to ensure UserPreferences: \(error)")
        }
    }
}
