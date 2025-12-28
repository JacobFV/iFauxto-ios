import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @Query private var tags: [AssetTag]

    @State private var courageCount = 0
    @State private var showingCourageEasterEgg = false

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    var body: some View {
        NavigationStack {
            Form {
                homeScreenSection
                sortingSection
                aiTaggingSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Courage Counter", isPresented: $showingCourageEasterEgg) {
                Button("Okay, got it") { }
            } message: {
                Text("You've tapped the icon \(courageCount) times.\n\nRemember when Apple removed the headphone jack and called it \"courage\"? We have courage too - the courage to let you organize YOUR photos YOUR way.")
            }
        }
    }

    private var homeScreenSection: some View {
        Section {
            if let prefs = userPreferences {
                Picker("What greets you", selection: Binding(
                    get: { prefs.homeMode },
                    set: { prefs.homeMode = $0 }
                )) {
                    ForEach(HomeScreenMode.allCases) { mode in
                        HStack {
                            Image(systemName: mode.systemImage)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
            }
        } header: {
            Text("Home Screen")
        } footer: {
            Text("Unlike some fruit companies, we actually let you choose what you see when you open the app.")
        }
    }

    private var sortingSection: some View {
        Section {
            if let prefs = userPreferences {
                Picker("Default folder sort", selection: Binding(
                    get: { prefs.folderSort },
                    set: { prefs.folderSort = $0 }
                )) {
                    ForEach(FolderSortOption.allCases) { option in
                        HStack {
                            Image(systemName: option.systemImage)
                            Text(option.rawValue)
                        }
                        .tag(option)
                    }
                }
            }
        } header: {
            Text("Sorting")
        } footer: {
            Text("Your custom order stays YOUR custom order. We won't \"helpfully\" reorganize things when you're not looking.")
        }
    }

    private var aiTaggingSection: some View {
        Section {
            if let prefs = userPreferences {
                Toggle("Enable AI Tagging", isOn: Binding(
                    get: { prefs.taggingEnabled },
                    set: { prefs.taggingEnabled = $0 }
                ))
            }

            HStack {
                Text("Photos Tagged")
                Spacer()
                Text("\(Set(tags.map(\.assetIdentifier)).count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Total Tags")
                Spacer()
                Text("\(tags.count)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AI Tagging")
        } footer: {
            Text("All processing happens on YOUR device. Your photos never leave your phone. Unlike... well, you know who.")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                    .onTapGesture {
                        courageCount += 1
                        if courageCount >= 10 {
                            showingCourageEasterEgg = true
                            courageCount = 0
                        }
                    }

                VStack(alignment: .leading) {
                    Text("iFauxto")
                        .font(.headline)
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)

            Text("Photos organized YOUR way, not the way some trillion-dollar company thinks is best for you.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("About")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserPreferences.self, AssetTag.self], inMemory: true)
}
