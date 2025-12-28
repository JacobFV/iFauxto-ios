import Photos
import UIKit
import SwiftUI

@Observable
final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private(set) var isLoading = false

    private let imageManager = PHCachingImageManager()
    private var imageCache = NSCache<NSString, UIImage>()

    private init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        imageCache.countLimit = 500
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func fetchAllAssets(sortOrder: PhotoSortOrder = .newest) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldest)]
        options.includeHiddenAssets = false
        return PHAsset.fetchAssets(with: options)
    }

    func fetchAssets(identifiers: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    func fetchAsset(identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject
    }

    func thumbnail(for asset: PHAsset, size: CGSize) async -> UIImage? {
        let cacheKey = "\(asset.localIdentifier)_\(Int(size.width))x\(Int(size.height))" as NSString

        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                if let image = image {
                    self?.imageCache.setObject(image, forKey: cacheKey)
                }

                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func fullSizeImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func cgImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    func startCaching(assets: [PHAsset], size: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopCaching(assets: [PHAsset], size: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopAllCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    func assetCreationDate(_ asset: PHAsset) -> Date? {
        asset.creationDate
    }

    func assetLocation(_ asset: PHAsset) -> CLLocation? {
        asset.location
    }
}

enum PhotoSortOrder {
    case newest
    case oldest
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
