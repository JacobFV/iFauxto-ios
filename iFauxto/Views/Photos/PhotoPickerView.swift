import SwiftUI
import Photos

struct PhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var photoService = PhotoLibraryService.shared
    @State private var assets: [PHAsset] = []
    @State private var selectedIdentifiers: Set<String> = []
    @State private var isLoading = true

    let onSelect: ([String]) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading photos...")
                } else {
                    photoGrid
                }
            }
            .navigationTitle("Select Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedIdentifiers.count)") {
                        onSelect(Array(selectedIdentifiers))
                        dismiss()
                    }
                    .disabled(selectedIdentifiers.isEmpty)
                }
            }
            .task {
                await loadPhotos()
            }
        }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets) { asset in
                    SelectablePhotoCell(
                        asset: asset,
                        isSelected: selectedIdentifiers.contains(asset.localIdentifier)
                    ) {
                        toggleSelection(asset.localIdentifier)
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

    private func toggleSelection(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
        }

        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

struct SelectablePhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var photoService = PhotoLibraryService.shared

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // Photo
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

                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(.blue.opacity(0.3))
                        .frame(width: geo.size.width, height: geo.size.height)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                        .padding(6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .task {
            let size = CGSize(width: 150, height: 150)
            image = await photoService.thumbnail(for: asset, size: size)
        }
    }
}

#Preview {
    PhotoPickerView { identifiers in
        print("Selected: \(identifiers)")
    }
}
