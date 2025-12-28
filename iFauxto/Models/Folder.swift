import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \FolderAsset.folder)
    var assets: [FolderAsset]? = []

    // Nested folder support
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var subfolders: [Folder]? = []

    var parent: Folder?

    init(name: String, sortOrder: Int = 0, isFavorite: Bool = false, parent: Folder? = nil) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.isFavorite = isFavorite
        self.parent = parent
        self.createdAt = Date()
        self.updatedAt = Date()
        self.assets = []
        self.subfolders = []
    }

    var safeAssets: [FolderAsset] {
        assets ?? []
    }

    var safeSubfolders: [Folder] {
        subfolders ?? []
    }
}

enum FolderSortOption: String, CaseIterable, Identifiable {
    case custom = "My Order (God's Way)"
    case alphabetical = "A-Z (Boring)"
    case mostRecent = "Most Recent (Apple's Favorite)"
    case chronological = "Oldest First (Archaeologist Mode)"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .custom: return "hand.point.up.left.fill"
        case .alphabetical: return "textformat.abc"
        case .mostRecent: return "clock.arrow.circlepath"
        case .chronological: return "calendar"
        }
    }
}
