import SwiftUI
import SwiftData
import Photos

struct AllPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @State private var photoService = PhotoLibraryService.shared
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedAsset: PHAsset?

    // Drag and drop state
    @State private var draggingPhotoId: String?
    @State private var hoveredFolderId: UUID?
    @State private var hoveredPhotoId: String?
    @State private var hoveredDropZone: PhotoDropZone = .none
    @State private var photoOrder: [String] = []

    // New folder creation
    @State private var pendingFolderPhotoIds: [String] = []
    @State private var showingCreateFolderSheet = false

    private let photoColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private let folderColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading all your photos...")
            } else if assets.isEmpty {
                emptyState
            } else {
                photosContent
            }
        }
        .navigationTitle("All Photos")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadPhotos()
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, folder: nil)
        }
        .fullScreenCover(isPresented: $showingCreateFolderSheet) {
            FolderEditSheet(mode: .create) { name in
                createFolderFromPhotos(name: name, photoIds: pendingFolderPhotoIds)
                pendingFolderPhotoIds = []
            }
            .presentationBackground(.clear)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Photos", systemImage: "photo.on.rectangle")
        } description: {
            Text("Your photo library is empty.\nTime to start capturing some memories!")
        }
    }

    private var photosContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Folders section - drop targets
                if !folders.isEmpty {
                    foldersDropSection
                }

                // Photos grid
                photosGrid
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Folders Drop Section
    private var foldersDropSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drag photos to a folder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(folders, id: \.id) { folder in
                        FolderDropTarget(
                            folder: folder,
                            isHovered: hoveredFolderId == folder.id
                        )
                        .onDrop(of: [.text], delegate: FolderDropDelegate(
                            folder: folder,
                            draggingPhotoId: $draggingPhotoId,
                            hoveredFolderId: $hoveredFolderId,
                            onDrop: { photoId in
                                addPhotoToFolder(photoId: photoId, folder: folder)
                            }
                        ))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Photos Grid
    private var photosGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(assets.count) photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Drag to reorder or create folders")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: photoColumns, spacing: 2) {
                ForEach(orderedAssets, id: \.localIdentifier) { asset in
                    let isHovered = hoveredPhotoId == asset.localIdentifier
                    let currentDropZone = isHovered ? hoveredDropZone : .none

                    DraggablePhotoCell(
                        asset: asset,
                        isDragging: draggingPhotoId == asset.localIdentifier,
                        dropZone: currentDropZone
                    )
                    .onTapGesture {
                        selectedAsset = asset
                    }
                    .draggable(asset.localIdentifier) {
                        PhotoGridCell(asset: asset)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onAppear {
                                draggingPhotoId = asset.localIdentifier
                                // Initialize order if empty
                                if photoOrder.isEmpty {
                                    photoOrder = assets.map(\.localIdentifier)
                                }
                            }
                    }
                    .onDrop(of: [.text], delegate: AllPhotosDropDelegate(
                        targetAssetId: asset.localIdentifier,
                        draggingPhotoId: $draggingPhotoId,
                        hoveredPhotoId: $hoveredPhotoId,
                        hoveredDropZone: $hoveredDropZone,
                        onCreateFolder: { droppedId, targetId in
                            pendingFolderPhotoIds = [droppedId, targetId]
                            showingCreateFolderSheet = true
                            triggerHaptic()
                        }
                    ))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var orderedAssets: [PHAsset] {
        if photoOrder.isEmpty {
            return assets
        }
        // Return photos in custom order if set
        var ordered: [PHAsset] = []
        for id in photoOrder {
            if let asset = assets.first(where: { $0.localIdentifier == id }) {
                ordered.append(asset)
            }
        }
        // Add any photos not in the order yet
        for asset in assets {
            if !photoOrder.contains(asset.localIdentifier) {
                ordered.append(asset)
            }
        }
        return ordered
    }

    // MARK: - Actions
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

    private func addPhotoToFolder(photoId: String, folder: Folder) {
        // Check if photo is already in folder
        let existingIds = folder.safeAssets.map(\.assetIdentifier)
        guard !existingIds.contains(photoId) else {
            triggerHaptic(style: .light)
            return
        }

        let maxSortOrder = folder.safeAssets.map(\.sortOrder).max() ?? -1
        let asset = FolderAsset(assetIdentifier: photoId, sortOrder: maxSortOrder + 1)
        asset.folder = folder
        modelContext.insert(asset)
        folder.updatedAt = Date()

        triggerHaptic()
        draggingPhotoId = nil
        hoveredFolderId = nil
    }

    private func createFolderFromPhotos(name: String, photoIds: [String]) {
        let maxSortOrder = folders.map(\.sortOrder).max() ?? -1
        let folder = Folder(name: name, sortOrder: maxSortOrder + 1)
        modelContext.insert(folder)

        for (index, photoId) in photoIds.enumerated() {
            let asset = FolderAsset(assetIdentifier: photoId, sortOrder: index)
            asset.folder = folder
            modelContext.insert(asset)
        }

        triggerHaptic()
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Folder Drop Target
struct FolderDropTarget: View {
    let folder: Folder
    let isHovered: Bool
    @State private var coverImage: UIImage?
    @State private var photoService = PhotoLibraryService.shared

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.blue.opacity(0.3) : Color(.secondarySystemBackground))
                    .frame(width: 70, height: 70)

                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isHovered ? 0.7 : 1)
                } else {
                    Image(systemName: "folder.fill")
                        .font(.title)
                        .foregroundStyle(isHovered ? .blue : .gray)
                }

                if isHovered {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                }
            }
            .overlay {
                if isHovered {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 3)
                }
            }

            Text(folder.name)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 70)
        }
        .task {
            await loadCoverImage()
        }
    }

    private func loadCoverImage() async {
        guard let firstId = folder.allAssetIdentifiers.first,
              let asset = photoService.fetchAsset(identifier: firstId) else {
            return
        }
        coverImage = await photoService.thumbnail(for: asset, size: CGSize(width: 140, height: 140))
    }
}

// MARK: - Folder Drop Delegate
struct FolderDropDelegate: DropDelegate {
    let folder: Folder
    @Binding var draggingPhotoId: String?
    @Binding var hoveredFolderId: UUID?
    let onDrop: (String) -> Void

    func dropEntered(info: DropInfo) {
        guard draggingPhotoId != nil else { return }
        hoveredFolderId = folder.id
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard draggingPhotoId != nil else {
            return DropProposal(operation: .cancel)
        }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        if hoveredFolderId == folder.id {
            hoveredFolderId = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let photoId = draggingPhotoId else {
            hoveredFolderId = nil
            return false
        }

        onDrop(photoId)
        hoveredFolderId = nil
        draggingPhotoId = nil
        return true
    }
}

// MARK: - All Photos Drop Delegate
struct AllPhotosDropDelegate: DropDelegate {
    let targetAssetId: String
    @Binding var draggingPhotoId: String?
    @Binding var hoveredPhotoId: String?
    @Binding var hoveredDropZone: PhotoDropZone
    let onCreateFolder: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard draggingPhotoId != nil, draggingPhotoId != targetAssetId else { return }
        hoveredPhotoId = targetAssetId
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let draggingId = draggingPhotoId, draggingId != targetAssetId else {
            return DropProposal(operation: .cancel)
        }

        // Always show center zone (create folder) for all photos view
        if hoveredDropZone != .center {
            hoveredDropZone = .center
            hoveredPhotoId = targetAssetId
        }

        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if hoveredPhotoId == targetAssetId {
            hoveredPhotoId = nil
            hoveredDropZone = .none
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingId = draggingPhotoId, draggingId != targetAssetId else {
            cleanup()
            return false
        }

        // Create folder from the two photos
        onCreateFolder(draggingId, targetAssetId)
        cleanup()
        return true
    }

    private func cleanup() {
        hoveredPhotoId = nil
        hoveredDropZone = .none
        draggingPhotoId = nil
    }
}

#Preview {
    NavigationStack {
        AllPhotosView()
    }
    .modelContainer(for: [Folder.self], inMemory: true)
}
