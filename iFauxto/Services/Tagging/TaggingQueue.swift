import Foundation
import SwiftData
import Photos

@Observable
final class TaggingQueue {
    static let shared = TaggingQueue()

    private(set) var isProcessing = false
    private(set) var processedCount = 0
    private(set) var totalCount = 0
    private(set) var currentProgress: Double = 0

    private let taggingService: ImageTaggingService = VisionTaggingService.shared
    private let photoService = PhotoLibraryService.shared
    private var processingTask: Task<Void, Never>?

    private init() {}

    var progressDescription: String {
        if !isProcessing { return "Ready" }
        return "Processing \(processedCount)/\(totalCount)"
    }

    func startProcessing(modelContext: ModelContext) {
        guard !isProcessing else { return }

        processingTask = Task {
            await processUntaggedPhotos(modelContext: modelContext)
        }
    }

    func stopProcessing() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
    }

    private func processUntaggedPhotos(modelContext: ModelContext) async {
        await MainActor.run {
            isProcessing = true
            processedCount = 0
        }

        let fetchResult = photoService.fetchAllAssets(sortOrder: .newest)
        var allIdentifiers: [String] = []

        fetchResult.enumerateObjects { asset, _, _ in
            allIdentifiers.append(asset.localIdentifier)
        }

        let taggedDescriptor = FetchDescriptor<AssetTag>()
        let existingTags: [AssetTag]
        do {
            existingTags = try modelContext.fetch(taggedDescriptor)
        } catch {
            print("Failed to fetch existing tags: \(error)")
            await MainActor.run { isProcessing = false }
            return
        }

        let taggedIdentifiers = Set(existingTags.map(\.assetIdentifier))
        let untaggedIdentifiers = allIdentifiers.filter { !taggedIdentifiers.contains($0) }

        await MainActor.run {
            totalCount = untaggedIdentifiers.count
        }

        for identifier in untaggedIdentifiers {
            if Task.isCancelled { break }

            await processAsset(identifier: identifier, modelContext: modelContext)

            await MainActor.run {
                processedCount += 1
                currentProgress = Double(processedCount) / Double(totalCount)
            }

            try? await Task.sleep(for: .milliseconds(100))
        }

        await MainActor.run {
            isProcessing = false
        }
    }

    private func processAsset(identifier: String, modelContext: ModelContext) async {
        guard let asset = photoService.fetchAsset(identifier: identifier),
              let cgImage = await photoService.cgImage(for: asset) else {
            return
        }

        do {
            let tags = try await taggingService.analyze(cgImage, assetIdentifier: identifier)

            await MainActor.run {
                for tag in tags {
                    modelContext.insert(tag)
                }

                if let date = asset.creationDate {
                    let dateTag = AssetTag(
                        assetIdentifier: identifier,
                        tagType: .date,
                        value: formatDate(date),
                        confidence: 1.0
                    )
                    modelContext.insert(dateTag)
                }

                try? modelContext.save()
            }
        } catch {
            print("Failed to process asset \(identifier): \(error)")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func tagAsset(identifier: String, modelContext: ModelContext) async {
        await processAsset(identifier: identifier, modelContext: modelContext)
    }
}
