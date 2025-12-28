import SwiftUI
import SwiftData
import Photos
import UniformTypeIdentifiers

struct FolderDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var folder: Folder
    @State private var photoService = PhotoLibraryService.shared
    @State private var showingPhotoPicker = false
    @State private var showingEditSheet = false
    @State private var selectedAsset: PHAsset?
    @State private var draggingAssetId: String?
    @State private var hoveredAssetId: String?
    @State private var hoveredDropZone: FolderPhotoDropZone = .none
    @State private var pendingSubfolderPhotoIds: [String] = []
    @State private var showingCreateSubfolderSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var sortedAssets: [FolderAsset] {
        folder.safeAssets.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            if folder.safeAssets.isEmpty {
                emptyState
            } else {
                photoGrid
            }
        }
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    folder.isFavorite.toggle()
                    triggerHaptic()
                } label: {
                    Image(systemName: folder.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(folder.isFavorite ? .pink : .primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Rename Folder", systemImage: "pencil")
                    }

                    Button {
                        folder.isFavorite.toggle()
                        triggerHaptic()
                    } label: {
                        Label(
                            folder.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: folder.isFavorite ? "heart.slash" : "heart"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView { identifiers in
                addPhotos(identifiers: identifiers)
            }
        }
        .fullScreenCover(isPresented: $showingEditSheet) {
            FolderEditSheet(mode: .edit(folder.name)) { newName in
                folder.name = newName
                folder.updatedAt = Date()
            }
            .presentationBackground(.clear)
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, folder: folder)
        }
        .fullScreenCover(isPresented: $showingCreateSubfolderSheet) {
            FolderEditSheet(mode: .create) { name in
                createSubfolder(name: name, photoIds: pendingSubfolderPhotoIds)
                pendingSubfolderPhotoIds = []
            }
            .presentationBackground(.clear)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Photos", systemImage: "photo.on.rectangle")
        } description: {
            Text("This folder is empty.\nTap + to add photos from your library.")
        } actions: {
            Button {
                showingPhotoPicker = true
            } label: {
                Text("Add Photos")
            }
        }
    }

    private var sortedSubfolders: [Folder] {
        folder.safeSubfolders.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                // Subfolders first
                ForEach(sortedSubfolders, id: \.id) { subfolder in
                    NavigationLink {
                        FolderDetailView(folder: subfolder)
                    } label: {
                        SubfolderCell(folder: subfolder)
                    }
                    .buttonStyle(.plain)
                }

                // Then photos
                ForEach(sortedAssets) { folderAsset in
                    let isHovered = hoveredAssetId == folderAsset.assetIdentifier
                    let currentDropZone = isHovered ? hoveredDropZone : .none

                    FolderPhotoCell(
                        assetIdentifier: folderAsset.assetIdentifier,
                        isDragging: draggingAssetId == folderAsset.assetIdentifier,
                        dropZone: currentDropZone
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let asset = photoService.fetchAsset(identifier: folderAsset.assetIdentifier) {
                            selectedAsset = asset
                        }
                    }
                    .draggable(folderAsset.assetIdentifier) {
                        PhotoThumbnail(assetIdentifier: folderAsset.assetIdentifier)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onAppear { draggingAssetId = folderAsset.assetIdentifier }
                    }
                    .onDrop(of: [.text], delegate: FolderPhotoDropDelegate(
                        targetAssetId: folderAsset.assetIdentifier,
                        draggingAssetId: $draggingAssetId,
                        hoveredAssetId: $hoveredAssetId,
                        hoveredDropZone: $hoveredDropZone,
                        sortedAssets: sortedAssets,
                        onReorder: { source, target, insertBefore in
                            reorderAssetLive(source: source, target: target, insertBefore: insertBefore)
                        },
                        onCreateSubfolder: { droppedId, targetId in
                            pendingSubfolderPhotoIds = [droppedId, targetId]
                            showingCreateSubfolderSheet = true
                            triggerHaptic()
                        },
                        onComplete: { triggerHaptic() }
                    ))
                    .contextMenu {
                        Button(role: .destructive) {
                            removeAsset(folderAsset)
                        } label: {
                            Label("Remove from Folder", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func addPhotos(identifiers: [String]) {
        let maxSortOrder = folder.safeAssets.map(\.sortOrder).max() ?? -1

        for (index, identifier) in identifiers.enumerated() {
            let existing = folder.safeAssets.first { $0.assetIdentifier == identifier }
            if existing == nil {
                let asset = FolderAsset(assetIdentifier: identifier, sortOrder: maxSortOrder + index + 1)
                asset.folder = folder
                modelContext.insert(asset)
            }
        }

        folder.updatedAt = Date()
        triggerHaptic()
    }

    private func reorderAssetLive(source: FolderAsset, target: FolderAsset, insertBefore: Bool) {
        var orderedAssets = sortedAssets
        guard let sourceIndex = orderedAssets.firstIndex(where: { $0.id == source.id }),
              let targetIndex = orderedAssets.firstIndex(where: { $0.id == target.id }),
              sourceIndex != targetIndex else {
            return
        }

        // Calculate new index
        var newIndex = insertBefore ? targetIndex : targetIndex + 1
        if sourceIndex < targetIndex {
            newIndex -= 1
        }

        guard newIndex != sourceIndex, newIndex >= 0 else { return }

        orderedAssets.remove(at: sourceIndex)
        orderedAssets.insert(source, at: min(newIndex, orderedAssets.count))

        for (index, asset) in orderedAssets.enumerated() {
            asset.sortOrder = index
        }

        folder.updatedAt = Date()
    }

    private func removeAsset(_ asset: FolderAsset) {
        modelContext.delete(asset)
        folder.updatedAt = Date()
        triggerHaptic()
    }

    private func createSubfolder(name: String, photoIds: [String]) {
        let maxSortOrder = folder.safeSubfolders.map(\.sortOrder).max() ?? -1
        let subfolder = Folder(name: name, sortOrder: maxSortOrder + 1, parent: folder)
        modelContext.insert(subfolder)

        // Add photos to the subfolder and remove from current folder
        for (index, photoId) in photoIds.enumerated() {
            // Create new asset in subfolder
            let newAsset = FolderAsset(assetIdentifier: photoId, sortOrder: index)
            newAsset.folder = subfolder
            modelContext.insert(newAsset)

            // Remove from current folder
            if let existingAsset = folder.safeAssets.first(where: { $0.assetIdentifier == photoId }) {
                modelContext.delete(existingAsset)
            }
        }

        folder.updatedAt = Date()
        triggerHaptic()
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct PhotoThumbnail: View {
    let assetIdentifier: String
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
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let asset = photoService.fetchAsset(identifier: assetIdentifier) else { return }
        let size = CGSize(width: 200, height: 200)
        image = await photoService.thumbnail(for: asset, size: size)
    }
}

// MARK: - Subfolder Cell
struct SubfolderCell: View {
    let folder: Folder
    @State private var coverImage: UIImage?
    @State private var photoService = PhotoLibraryService.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Cover image or gradient
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // Folder overlay
                Color.black.opacity(0.3)

                // Folder icon and name
                VStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text(folder.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(folder.safeAssets.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task {
            await loadCover()
        }
    }

    private func loadCover() async {
        guard let firstAsset = folder.safeAssets.first,
              let asset = photoService.fetchAsset(identifier: firstAsset.assetIdentifier) else {
            return
        }

        coverImage = await photoService.thumbnail(for: asset, size: CGSize(width: 200, height: 200))
    }
}

// MARK: - Drop Zone
enum FolderPhotoDropZone {
    case left
    case center
    case right
    case none
}

// MARK: - Folder Photo Cell
struct FolderPhotoCell: View {
    let assetIdentifier: String
    let isDragging: Bool
    let dropZone: FolderPhotoDropZone

    var body: some View {
        ZStack {
            PhotoThumbnail(assetIdentifier: assetIdentifier)

            // Drop zone indicators
            if dropZone == .left {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4)
                    Spacer()
                }
            } else if dropZone == .right {
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 4)
                }
            } else if dropZone == .center {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green, lineWidth: 3)

                Color.green.opacity(0.2)

                Image(systemName: "folder.badge.plus")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .opacity(isDragging ? 0.5 : 1)
    }
}

// MARK: - Folder Photo Drop Delegate
struct FolderPhotoDropDelegate: DropDelegate {
    let targetAssetId: String
    @Binding var draggingAssetId: String?
    @Binding var hoveredAssetId: String?
    @Binding var hoveredDropZone: FolderPhotoDropZone
    let sortedAssets: [FolderAsset]
    let onReorder: (FolderAsset, FolderAsset, Bool) -> Void
    let onCreateSubfolder: (String, String) -> Void  // (droppedId, targetId)
    let onComplete: () -> Void

    private let edgeThreshold: CGFloat = 0.25 // 25% from each edge

    func dropEntered(info: DropInfo) {
        guard draggingAssetId != nil, draggingAssetId != targetAssetId else { return }
        hoveredAssetId = targetAssetId
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let draggingId = draggingAssetId, draggingId != targetAssetId else {
            return DropProposal(operation: .cancel)
        }

        // Get the drop location relative to the view
        let location = info.location

        // For a 3-column grid on ~390pt screen, each cell is ~130pt
        let estimatedCellWidth: CGFloat = 130

        let relativeX = location.x / estimatedCellWidth
        let fractionalX = relativeX - floor(relativeX) // 0.0 to 1.0 within cell

        let newZone: FolderPhotoDropZone
        if fractionalX < edgeThreshold {
            newZone = .left
        } else if fractionalX > (1.0 - edgeThreshold) {
            newZone = .right
        } else {
            newZone = .center
        }

        // Update zone if changed
        if hoveredDropZone != newZone {
            hoveredDropZone = newZone
            hoveredAssetId = targetAssetId

            // Live reorder on edge zones
            if newZone == .left || newZone == .right {
                if let sourceAsset = sortedAssets.first(where: { $0.assetIdentifier == draggingId }),
                   let targetAsset = sortedAssets.first(where: { $0.assetIdentifier == targetAssetId }) {
                    onReorder(sourceAsset, targetAsset, newZone == .left)
                }
            }
        }

        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if hoveredAssetId == targetAssetId {
            hoveredAssetId = nil
            hoveredDropZone = .none
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingId = draggingAssetId, draggingId != targetAssetId else {
            cleanup()
            return false
        }

        // If dropping on center zone, create subfolder
        if hoveredDropZone == .center {
            onCreateSubfolder(draggingId, targetAssetId)
        }

        cleanup()
        onComplete()
        return true
    }

    private func cleanup() {
        hoveredAssetId = nil
        hoveredDropZone = .none
        draggingAssetId = nil
    }
}

#Preview {
    NavigationStack {
        FolderDetailView(folder: Folder(name: "Test Folder"))
    }
    .modelContainer(for: [Folder.self, FolderAsset.self], inMemory: true)
}
