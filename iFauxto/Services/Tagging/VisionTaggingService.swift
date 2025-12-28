import Vision
import CoreGraphics
import Foundation

final class VisionTaggingService: ImageTaggingService, @unchecked Sendable {
    static let shared = VisionTaggingService()

    private init() {}

    @MainActor
    func analyze(_ image: CGImage, assetIdentifier: String) async throws -> [AssetTag] {
        var tags: [AssetTag] = []

        async let objectTags = detectObjects(in: image, assetIdentifier: assetIdentifier)
        async let faceTags = detectFaces(in: image, assetIdentifier: assetIdentifier)
        async let textTags = detectText(in: image, assetIdentifier: assetIdentifier)
        async let sceneTags = classifyScene(in: image, assetIdentifier: assetIdentifier)

        let results = await (objectTags, faceTags, textTags, sceneTags)
        tags.append(contentsOf: results.0)
        tags.append(contentsOf: results.1)
        tags.append(contentsOf: results.2)
        tags.append(contentsOf: results.3)

        return tags
    }

    private func detectObjects(in image: CGImage, assetIdentifier: String) async -> [AssetTag] {
        await withCheckedContinuation { continuation in
            var tags: [AssetTag] = []

            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let significantResults = results.filter { $0.confidence > 0.5 }
                    .prefix(10)

                for result in significantResults {
                    let tag = AssetTag(
                        assetIdentifier: assetIdentifier,
                        tagType: .object,
                        value: result.identifier.replacingOccurrences(of: "_", with: " "),
                        confidence: Double(result.confidence)
                    )
                    tags.append(tag)
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Object detection failed: \(error)")
            }

            continuation.resume(returning: tags)
        }
    }

    private func detectFaces(in image: CGImage, assetIdentifier: String) async -> [AssetTag] {
        await withCheckedContinuation { continuation in
            var tags: [AssetTag] = []

            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                if !results.isEmpty {
                    let tag = AssetTag(
                        assetIdentifier: assetIdentifier,
                        tagType: .person,
                        value: "person",
                        confidence: Double(results.first?.confidence ?? 1.0)
                    )
                    tags.append(tag)

                    if results.count > 1 {
                        let groupTag = AssetTag(
                            assetIdentifier: assetIdentifier,
                            tagType: .person,
                            value: "group (\(results.count) people)",
                            confidence: 1.0
                        )
                        tags.append(groupTag)
                    }
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Face detection failed: \(error)")
            }

            continuation.resume(returning: tags)
        }
    }

    private func detectText(in image: CGImage, assetIdentifier: String) async -> [AssetTag] {
        await withCheckedContinuation { continuation in
            var tags: [AssetTag] = []

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                var foundText: [String] = []
                for observation in results.prefix(5) {
                    if let topCandidate = observation.topCandidates(1).first,
                       topCandidate.confidence > 0.5 {
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.count >= 3 && text.count <= 50 {
                            foundText.append(text)
                        }
                    }
                }

                for text in foundText {
                    let tag = AssetTag(
                        assetIdentifier: assetIdentifier,
                        tagType: .text,
                        value: text,
                        confidence: 0.8
                    )
                    tags.append(tag)
                }

                if !foundText.isEmpty {
                    let docTag = AssetTag(
                        assetIdentifier: assetIdentifier,
                        tagType: .object,
                        value: "document",
                        confidence: 0.7
                    )
                    tags.append(docTag)
                }
            }

            request.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Text detection failed: \(error)")
            }

            continuation.resume(returning: tags)
        }
    }

    private func classifyScene(in image: CGImage, assetIdentifier: String) async -> [AssetTag] {
        await withCheckedContinuation { continuation in
            var tags: [AssetTag] = []

            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let sceneKeywords = ["outdoor", "indoor", "beach", "mountain", "city", "forest",
                                     "restaurant", "office", "home", "park", "street", "sky",
                                     "water", "sunset", "night", "concert", "stadium", "museum"]

                let sceneResults = results.filter { observation in
                    let identifier = observation.identifier.lowercased()
                    return sceneKeywords.contains { identifier.contains($0) } && observation.confidence > 0.3
                }.prefix(3)

                for result in sceneResults {
                    let tag = AssetTag(
                        assetIdentifier: assetIdentifier,
                        tagType: .scene,
                        value: result.identifier.replacingOccurrences(of: "_", with: " "),
                        confidence: Double(result.confidence)
                    )
                    tags.append(tag)
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Scene classification failed: \(error)")
            }

            continuation.resume(returning: tags)
        }
    }
}
