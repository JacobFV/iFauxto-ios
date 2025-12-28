import Foundation
import SwiftData

@Model
final class UserPreferences {
    var id: UUID = UUID()
    var homeScreenMode: String = "Folders (The Order)"
    var defaultFolderSort: String = "My Order (God's Way)"
    var hasCompletedOnboarding: Bool = false
    var taggingEnabled: Bool = true
    var lastTaggingDate: Date?

    init() {
        self.id = UUID()
        self.homeScreenMode = HomeScreenMode.folders.rawValue
        self.defaultFolderSort = FolderSortOption.custom.rawValue
        self.hasCompletedOnboarding = false
        self.taggingEnabled = true
        self.lastTaggingDate = nil
    }

    var homeMode: HomeScreenMode {
        get { HomeScreenMode(rawValue: homeScreenMode) ?? .folders }
        set { homeScreenMode = newValue.rawValue }
    }

    var folderSort: FolderSortOption {
        get { FolderSortOption(rawValue: defaultFolderSort) ?? .custom }
        set { defaultFolderSort = newValue.rawValue }
    }
}

enum HomeScreenMode: String, CaseIterable, Identifiable {
    case photos = "All Photos (The Chaos)"
    case folders = "Folders (The Order)"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .photos: return "All Photos"
        case .folders: return "Folders"
        }
    }

    var systemImage: String {
        switch self {
        case .photos: return "photo.on.rectangle.angled"
        case .folders: return "folder.fill"
        }
    }

    var snarkyDescription: String {
        switch self {
        case .photos: return "Embrace the beautiful mess. Every photo, no algorithm deciding what you see."
        case .folders: return "Your folders, your order. Unlike Apple, we won't rearrange them when you're not looking."
        }
    }
}
