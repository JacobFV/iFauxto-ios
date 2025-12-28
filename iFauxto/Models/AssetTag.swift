import Foundation
import SwiftData

@Model
final class AssetTag {
    var id: UUID = UUID()
    var assetIdentifier: String = ""
    var tagType: String = "object"
    var value: String = ""
    var confidence: Double = 1.0
    var createdAt: Date = Date()

    init(assetIdentifier: String, tagType: TagType, value: String, confidence: Double = 1.0) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.tagType = tagType.rawValue
        self.value = value
        self.confidence = confidence
        self.createdAt = Date()
    }

    var type: TagType {
        TagType(rawValue: tagType) ?? .object
    }
}

enum TagType: String, CaseIterable {
    case person = "person"
    case object = "object"
    case scene = "scene"
    case text = "text"
    case location = "location"
    case date = "date"
    case color = "color"

    var displayName: String {
        switch self {
        case .person: return "People"
        case .object: return "Objects"
        case .scene: return "Scenes"
        case .text: return "Text"
        case .location: return "Places"
        case .date: return "Dates"
        case .color: return "Colors"
        }
    }

    var systemImage: String {
        switch self {
        case .person: return "person.fill"
        case .object: return "cube.fill"
        case .scene: return "photo.fill"
        case .text: return "doc.text.fill"
        case .location: return "mappin.circle.fill"
        case .date: return "calendar"
        case .color: return "paintpalette.fill"
        }
    }
}
