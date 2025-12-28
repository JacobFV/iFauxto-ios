import SwiftUI
import Photos

struct PhotoFeedView: View {
    @State private var photoService = PhotoLibraryService.shared
    @State private var assets: [PHAsset] = []
    @State private var selectedAsset: PHAsset?
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading your masterpieces...")
            } else if assets.isEmpty {
                emptyState
            } else {
                photoGrid
            }
        }
        .task {
            await loadPhotos()
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, folder: nil)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Photos", systemImage: "photo.on.rectangle")
        } description: {
            Text("Your photo library is empty.\nTime to start capturing some memories!")
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets) { asset in
                    PhotoGridCell(asset: asset)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .onTapGesture {
                            selectedAsset = asset
                        }
                }
            }
        }
    }

    private func loadPhotos() async {
        let fetchResult = photoService.fetchAllAssets(sortOrder: .newest)
        var loadedAssets: [PHAsset] = []

        fetchResult.enumerateObjects { asset, _, _ in
            loadedAssets.append(asset)
        }

        await MainActor.run {
            assets = loadedAssets
            isLoading = false
        }
    }
}

struct PhotoGridCell: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var photoService = PhotoLibraryService.shared

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            let size = CGSize(width: 200, height: 200)
            image = await photoService.thumbnail(for: asset, size: size)
        }
    }
}

#Preview {
    PhotoFeedView()
}
