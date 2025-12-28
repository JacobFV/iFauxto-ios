import Foundation
import SwiftData

@Model
final class FolderAsset {
    var id: UUID = UUID()
    var assetIdentifier: String = ""
    var sortOrder: Int = 0
    var addedAt: Date = Date()

    var folder: Folder?

    init(assetIdentifier: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.sortOrder = sortOrder
        self.addedAt = Date()
    }
}
