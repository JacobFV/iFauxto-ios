import SwiftUI
import SwiftData
import Photos
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    @State private var photoService = PhotoLibraryService.shared
    @State private var recentPhotos: [PHAsset] = []
    @State private var showingNewFolder = false
    @State private var selectedAsset: PHAsset?
    @State private var heroImages: [UIImage] = []
    @State private var isLoadingHero = true

    // Drag and drop state
    @State private var draggingFolder: Folder?
    @State private var draggingPhotoId: String?
    @State private var pendingFolderPhotoIds: [String] = []
    @State private var showingCreateFolderSheet = false
    @State private var hoveredPhotoId: String?
    @State private var hoveredDropZone: PhotoDropZone = .none
    @State private var recentPhotoOrder: [String] = []

    // Folder overlay
    @State private var selectedFolder: Folder?
    @State private var folderOrigin: CGPoint = .zero
    @State private var folderPositions: [UUID: CGPoint] = [:]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection

                favoriteFoldersSection
                    .padding(.top, -40)
                    .padding(.horizontal, 20)

                foldersSection
                    .padding(.top, favoriteFolders.isEmpty ? -20 : 24)
                    .padding(.horizontal, 20)

                recentPhotosSection
                    .padding(.top, 32)
                    .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .task {
            await loadContent()
        }
        .fullScreenCover(isPresented: $showingNewFolder) {
            FolderEditSheet(mode: .create) { name in
                createFolder(name: name)
            }
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $showingCreateFolderSheet) {
            FolderEditSheet(mode: .create) { name in
                createFolderFromPhotos(name: name, photoIds: pendingFolderPhotoIds)
                pendingFolderPhotoIds = []
            }
            .presentationBackground(.clear)
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, folder: nil)
        }
        .overlay {
            if let folder = selectedFolder {
                FolderOverlayView(
                    folder: folder,
                    isPresented: Binding(
                        get: { selectedFolder != nil },
                        set: { if !$0 { selectedFolder = nil } }
                    ),
                    originPoint: folderOrigin
                )
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if heroImages.isEmpty {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 320)
            } else {
                heroCollage
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, Color(.systemBackground).opacity(0.8), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Title overlay
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Your Memories")
                    .font(.system(size: 34, weight: .bold))

                Text(statsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .frame(height: 320)
    }

    private var heroCollage: some View {
        GeometryReader { geo in
            if heroImages.count >= 3 {
                let leftWidth = geo.size.width * 0.55
                let rightWidth = geo.size.width * 0.45 - 2
                let halfHeight = (geo.size.height - 2) / 2

                HStack(spacing: 2) {
                    Image(uiImage: heroImages[0])
                        .resizable()
                        .scaledToFill()
                        .frame(width: leftWidth, height: geo.size.height)
                        .clipped()

                    VStack(spacing: 2) {
                        Image(uiImage: heroImages[1])
                            .resizable()
                            .scaledToFill()
                            .frame(width: rightWidth, height: halfHeight)
                            .clipped()

                        Image(uiImage: heroImages[2])
                            .resizable()
                            .scaledToFill()
                            .frame(width: rightWidth, height: halfHeight)
                            .clipped()
                    }
                }
            } else if let first = heroImages.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
        .frame(height: 320)
    }

    // MARK: - Favorite Folders Section
    private var favoriteFolders: [Folder] {
        folders.filter { $0.isFavorite }
    }

    @ViewBuilder
    private var favoriteFoldersSection: some View {
        if !favoriteFolders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Favorites")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(favoriteFolders, id: \.id) { folder in
                        FavoriteFolderCard(folder: folder)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        folderPositions[folder.id] = geo.frame(in: .global).center
                                    }
                                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                        folderPositions[folder.id] = newFrame.center
                                    }
                                }
                            )
                            .onTapGesture {
                                if let pos = folderPositions[folder.id] {
                                    folderOrigin = pos
                                }
                                selectedFolder = folder
                            }
                    }
                }
            }
        }
    }

    // MARK: - Folders Section (Grid, no horizontal scroll)
    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Folders")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !folders.isEmpty {
                    NavigationLink {
                        FolderListView()
                    } label: {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }

            if folders.isEmpty {
                emptyFoldersCard
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(folders.prefix(4), id: \.id) { folder in
                        FolderCard(folder: folder)
                            .opacity(draggingFolder?.id == folder.id ? 0.5 : 1)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        folderPositions[folder.id] = geo.frame(in: .global).center
                                    }
                                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                        folderPositions[folder.id] = newFrame.center
                                    }
                                }
                            )
                            .onTapGesture {
                                if let pos = folderPositions[folder.id] {
                                    folderOrigin = pos
                                }
                                selectedFolder = folder
                            }
                            .draggable(folder.id.uuidString) {
                                FolderCard(folder: folder)
                                    .frame(width: 120, height: 120)
                                    .onAppear { draggingFolder = folder }
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let droppedId = items.first,
                                      let droppedUUID = UUID(uuidString: droppedId),
                                      let sourceFolder = folders.first(where: { $0.id == droppedUUID }),
                                      sourceFolder.id != folder.id else {
                                    return false
                                }
                                reorderFolder(source: sourceFolder, target: folder)
                                return true
                            } isTargeted: { _ in }
                    }
                }
            }
        }
    }

    private var emptyFoldersCard: some View {
        Button {
            showingNewFolder = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)

                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create your first folder")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Unlike Apple, we won't auto-create albums you didn't ask for")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Photos
    private var orderedRecentPhotos: [PHAsset] {
        if recentPhotoOrder.isEmpty {
            return Array(recentPhotos.prefix(12))
        }
        // Return photos in custom order, with any new photos appended
        var ordered: [PHAsset] = []
        for id in recentPhotoOrder {
            if let asset = recentPhotos.first(where: { $0.localIdentifier == id }) {
                ordered.append(asset)
            }
        }
        // Add any photos not in the order yet
        for asset in recentPhotos.prefix(12) {
            if !recentPhotoOrder.contains(asset.localIdentifier) {
                ordered.append(asset)
            }
        }
        return ordered
    }

    private var recentPhotosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("Last 7 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if recentPhotos.isEmpty {
                Text("No recent photos")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ],
                    spacing: 2
                ) {
                    ForEach(orderedRecentPhotos, id: \.localIdentifier) { asset in
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
                                    if recentPhotoOrder.isEmpty {
                                        recentPhotoOrder = recentPhotos.prefix(12).map(\.localIdentifier)
                                    }
                                }
                        }
                        .onDrop(of: [.text], delegate: PhotoDropDelegate(
                            targetAssetId: asset.localIdentifier,
                            draggingPhotoId: $draggingPhotoId,
                            hoveredPhotoId: $hoveredPhotoId,
                            hoveredDropZone: $hoveredDropZone,
                            photoOrder: $recentPhotoOrder,
                            onReorder: { triggerHaptic() },
                            onCreateFolder: { droppedId, targetId in
                                pendingFolderPhotoIds = [droppedId, targetId]
                                showingCreateFolderSheet = true
                                triggerHaptic()
                            }
                        ))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var statsText: String {
        let folderCount = folders.count
        let photoCount = recentPhotos.count
        if folderCount == 0 {
            return "\(photoCount) photos ready to organize"
        }
        return "\(folderCount) folders · \(photoCount)+ photos"
    }

    private func loadContent() async {
        let fetchResult = photoService.fetchAllAssets(sortOrder: .newest)
        var assets: [PHAsset] = []

        fetchResult.enumerateObjects { asset, index, stop in
            assets.append(asset)
            if index >= 100 { stop.pointee = true }
        }

        await MainActor.run {
            recentPhotos = assets
        }

        // Load hero images
        let heroAssets = Array(assets.prefix(3))
        var images: [UIImage] = []

        for asset in heroAssets {
            if let image = await photoService.thumbnail(for: asset, size: CGSize(width: 600, height: 600)) {
                images.append(image)
            }
        }

        await MainActor.run {
            heroImages = images
            isLoadingHero = false
        }
    }

    private func createFolder(name: String) {
        let maxSortOrder = folders.map(\.sortOrder).max() ?? -1
        let folder = Folder(name: name, sortOrder: maxSortOrder + 1)
        modelContext.insert(folder)
        triggerHaptic()
    }

    private func createFolderFromPhotos(name: String, photoIds: [String]) {
        let maxSortOrder = folders.map(\.sortOrder).max() ?? -1
        let folder = Folder(name: name, sortOrder: maxSortOrder + 1)
        modelContext.insert(folder)

        // Add photos to the folder
        for (index, photoId) in photoIds.enumerated() {
            let asset = FolderAsset(assetIdentifier: photoId, sortOrder: index)
            asset.folder = folder
            modelContext.insert(asset)
        }

        triggerHaptic()
    }

    private func reorderFolder(source: Folder, target: Folder) {
        var orderedFolders = folders.sorted { $0.sortOrder < $1.sortOrder }
        guard let sourceIndex = orderedFolders.firstIndex(where: { $0.id == source.id }),
              let targetIndex = orderedFolders.firstIndex(where: { $0.id == target.id }) else {
            return
        }

        orderedFolders.remove(at: sourceIndex)
        orderedFolders.insert(source, at: targetIndex)

        for (index, folder) in orderedFolders.enumerated() {
            folder.sortOrder = index
            folder.updatedAt = Date()
        }

        draggingFolder = nil
        triggerHaptic()
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Drop Zone
enum PhotoDropZone {
    case left
    case center
    case right
    case none
}

// MARK: - Draggable Photo Cell
struct DraggablePhotoCell: View {
    let asset: PHAsset
    let isDragging: Bool
    let dropZone: PhotoDropZone

    var body: some View {
        ZStack {
            PhotoGridCell(asset: asset)

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
        .contentShape(Rectangle())
    }
}

// MARK: - Photo Drop Delegate
struct PhotoDropDelegate: DropDelegate {
    let targetAssetId: String
    @Binding var draggingPhotoId: String?
    @Binding var hoveredPhotoId: String?
    @Binding var hoveredDropZone: PhotoDropZone
    @Binding var photoOrder: [String]
    let onReorder: () -> Void
    let onCreateFolder: (String, String) -> Void  // (droppedId, targetId)

    private let edgeThreshold: CGFloat = 0.25 // 25% from each edge

    func dropEntered(info: DropInfo) {
        guard draggingPhotoId != nil, draggingPhotoId != targetAssetId else { return }
        hoveredPhotoId = targetAssetId
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let draggingId = draggingPhotoId, draggingId != targetAssetId else {
            return DropProposal(operation: .cancel)
        }

        // Get the drop location relative to the view
        let location = info.location

        // For a 3-column grid on ~390pt screen, each cell is ~130pt
        let estimatedCellWidth: CGFloat = 130

        let relativeX = location.x / estimatedCellWidth
        let fractionalX = relativeX - floor(relativeX) // 0.0 to 1.0 within cell

        let newZone: PhotoDropZone
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
            hoveredPhotoId = targetAssetId

            // Live reorder on edge zones
            if newZone == .left || newZone == .right {
                performReorder(insertBefore: newZone == .left)
            }
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

        // If dropping on center zone, immediately create folder
        if hoveredDropZone == .center {
            onCreateFolder(draggingId, targetAssetId)
        }
        // Edge drops already handled in dropUpdated

        cleanup()
        return true
    }

    private func performReorder(insertBefore: Bool) {
        guard let draggingId = draggingPhotoId,
              let sourceIndex = photoOrder.firstIndex(of: draggingId),
              let targetIndex = photoOrder.firstIndex(of: targetAssetId),
              sourceIndex != targetIndex else {
            return
        }

        // Calculate new index
        var newIndex = insertBefore ? targetIndex : targetIndex + 1
        if sourceIndex < targetIndex {
            newIndex -= 1
        }

        guard newIndex != sourceIndex, newIndex >= 0, newIndex < photoOrder.count else {
            return
        }

        // Move the item
        photoOrder.remove(at: sourceIndex)
        photoOrder.insert(draggingId, at: min(newIndex, photoOrder.count))
        onReorder()
    }

    private func cleanup() {
        hoveredPhotoId = nil
        hoveredDropZone = .none
        draggingPhotoId = nil
    }
}

// MARK: - Folder Card (Stacked Photos)
struct FolderCard: View {
    let folder: Folder
    @State private var stackImages: [UIImage] = []
    @State private var photoService = PhotoLibraryService.shared

    // Rotation angles for the stack effect
    private let rotations: [Double] = [-6, 3, 0]
    private let offsets: [(x: CGFloat, y: CGFloat)] = [(-4, 2), (3, -2), (0, 0)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let cardSize = geo.size.width * 0.85

                ZStack {
                    // Stacked images (back to front)
                    ForEach(Array(stackImages.prefix(3).enumerated().reversed()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cardSize, height: cardSize)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .rotationEffect(.degrees(rotations[safe: index] ?? 0))
                            .offset(x: offsets[safe: index]?.x ?? 0, y: offsets[safe: index]?.y ?? 0)
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
                    }

                    // Empty state
                    if stackImages.isEmpty {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(
                                colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: cardSize, height: cardSize)
                            .overlay {
                                Image(systemName: "folder.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("\(folder.safeAssets.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadStackImages()
        }
    }

    private func loadStackImages() async {
        let identifiers = folder.allAssetIdentifiers.prefix(3)
        var images: [UIImage] = []

        for identifier in identifiers {
            if let asset = photoService.fetchAsset(identifier: identifier),
               let image = await photoService.thumbnail(for: asset, size: CGSize(width: 200, height: 200)) {
                images.append(image)
            }
        }

        await MainActor.run {
            stackImages = images
        }
    }
}

// Safe array subscript extension
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// CGRect center extension
extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

// MARK: - Favorite Folder Card (Stacked)
struct FavoriteFolderCard: View {
    let folder: Folder
    @State private var stackImages: [UIImage] = []
    @State private var photoService = PhotoLibraryService.shared

    private let rotations: [Double] = [-5, 3, 0]
    private let offsets: [(x: CGFloat, y: CGFloat)] = [(-3, 2), (2, -1), (0, 0)]

    var body: some View {
        GeometryReader { geo in
            let cardSize = geo.size.width * 0.82

            ZStack {
                // Stacked images
                ForEach(Array(stackImages.prefix(3).enumerated().reversed()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardSize, height: cardSize)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .rotationEffect(.degrees(rotations[safe: index] ?? 0))
                        .offset(x: offsets[safe: index]?.x ?? 0, y: offsets[safe: index]?.y ?? 0)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }

                // Empty state
                if stackImages.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: cardSize, height: cardSize)
                }

                // Label overlay
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(folder.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text("\(folder.safeAssets.count)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(width: cardSize * 0.9)
                .padding(.bottom, 6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await loadStackImages()
        }
    }

    private func loadStackImages() async {
        let identifiers = folder.allAssetIdentifiers.prefix(3)
        var images: [UIImage] = []

        for identifier in identifiers {
            if let asset = photoService.fetchAsset(identifier: identifier),
               let image = await photoService.thumbnail(for: asset, size: CGSize(width: 200, height: 200)) {
                images.append(image)
            }
        }

        await MainActor.run {
            stackImages = images
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Folder.self, UserPreferences.self], inMemory: true)
}
