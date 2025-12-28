import Foundation
import CoreGraphics

protocol ImageTaggingService: Sendable {
    @MainActor func analyze(_ image: CGImage, assetIdentifier: String) async throws -> [AssetTag]
}

enum TaggingError: Error, LocalizedError {
    case analysisNotAvailable
    case processingFailed(String)
    case noResultsFound

    var errorDescription: String? {
        switch self {
        case .analysisNotAvailable:
            return "Image analysis is not available on this device"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .noResultsFound:
            return "No tags could be generated for this image"
        }
    }
}
