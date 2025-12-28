import SwiftUI
import SwiftData
import Photos
import UniformTypeIdentifiers

struct FolderOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var folder: Folder
    @Binding var isPresented: Bool
    let originPoint: CGPoint  // Where the folder card was on screen

    @State private var photoService = PhotoLibraryService.shared
    @State private var selectedAsset: PHAsset?
    @State private var animationProgress: CGFloat = 0
    @State private var selectedSubfolder: Folder?
    @State private var subfolderOrigin: CGPoint = .zero

    // Drag state
    @State private var draggingAssetId: String?
    @State private var hoveredAssetId: String?
    @State private var hoveredDropZone: FolderPhotoDropZone = .none
    @State private var pendingSubfolderPhotoIds: [String] = []
    @State private var showingCreateSubfolderSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var sortedAssets: [FolderAsset] {
        folder.safeAssets.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedSubfolders: [Folder] {
        folder.safeSubfolders.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func headerHeight(in geometry: GeometryProxy) -> CGFloat {
        geometry.safeAreaInsets.top + 60
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Solid background to hide underlying UI (search bar, etc)
                Rectangle()
                    .fill(Color(.systemBackground))
                    .opacity(animationProgress * 0.95)
                    .ignoresSafeArea()

                // Blur background on top
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(animationProgress)
                    .ignoresSafeArea()

                // Scrollable content - extends full screen, content starts below header
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                            // Subfolders first
                            ForEach(Array(sortedSubfolders.enumerated()), id: \.element.id) { index, subfolder in
                                let targetPosition = gridPosition(for: index, in: geometry)

                                SubfolderStackCard(folder: subfolder)
                                    .opacity(animationProgress)
                                    .scaleEffect(interpolate(from: 0.3, to: 1.0))
                                    .offset(
                                        x: interpolate(from: originPoint.x - targetPosition.x, to: 0),
                                        y: interpolate(from: originPoint.y - targetPosition.y - 200, to: 0)
                                    )
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.03),
                                        value: animationProgress
                                    )
                                    .highPriorityGesture(
                                        TapGesture().onEnded {
                                            let pos = gridPosition(for: index, in: geometry)
                                            subfolderOrigin = CGPoint(x: pos.x + 60, y: pos.y + 200)
                                            selectedSubfolder = subfolder
                                        }
                                    )
                            }

                            // Photos
                            ForEach(Array(sortedAssets.enumerated()), id: \.element.id) { index, folderAsset in
                                let adjustedIndex = index + sortedSubfolders.count
                                let targetPosition = gridPosition(for: adjustedIndex, in: geometry)
                                let isHovered = hoveredAssetId == folderAsset.assetIdentifier
                                let currentDropZone = isHovered ? hoveredDropZone : .none

                                OverlayPhotoCell(
                                    assetIdentifier: folderAsset.assetIdentifier,
                                    isDragging: draggingAssetId == folderAsset.assetIdentifier,
                                    dropZone: currentDropZone
                                )
                                .opacity(animationProgress)
                                .scaleEffect(interpolate(from: 0.3, to: 1.0))
                                .offset(
                                    x: interpolate(from: originPoint.x - targetPosition.x, to: 0),
                                    y: interpolate(from: originPoint.y - targetPosition.y - 200, to: 0)
                                )
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(adjustedIndex) * 0.03),
                                    value: animationProgress
                                )
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        if let asset = photoService.fetchAsset(identifier: folderAsset.assetIdentifier) {
                                            selectedAsset = asset
                                        }
                                    }
                                )
                                .draggable(folderAsset.assetIdentifier) {
                                    OverlayPhotoCell(assetIdentifier: folderAsset.assetIdentifier, isDragging: false, dropZone: .none)
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
                        .padding(.top, headerHeight(in: geometry))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                    .scrollClipDisabled()

                // Header blur - feathered bottom, more opaque to hide underlying UI
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(height: 280)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.4),
                                .init(color: .black.opacity(0), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                    .opacity(animationProgress)

                // Header title - aligned with settings button
                VStack {
                    Text(folder.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 15)
                .opacity(animationProgress)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                animationProgress = 1
            }
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
        .overlay {
            if let subfolder = selectedSubfolder {
                FolderOverlayView(
                    folder: subfolder,
                    isPresented: Binding(
                        get: { selectedSubfolder != nil },
                        set: { if !$0 { selectedSubfolder = nil } }
                    ),
                    originPoint: subfolderOrigin
                )
            }
        }
    }

    // Calculate where each grid item should be
    private func gridPosition(for index: Int, in geometry: GeometryProxy) -> CGPoint {
        let columnsCount = 3
        let spacing: CGFloat = 8
        let padding: CGFloat = 20
        let availableWidth = geometry.size.width - (padding * 2) - (spacing * CGFloat(columnsCount - 1))
        let itemWidth = availableWidth / CGFloat(columnsCount)

        let col = index % columnsCount
        let row = index / columnsCount

        let x = padding + (CGFloat(col) * (itemWidth + spacing)) + (itemWidth / 2)
        let y = headerHeight(in: geometry) + (CGFloat(row) * (itemWidth + spacing)) + (itemWidth / 2)

        return CGPoint(x: x, y: y)
    }

    private func interpolate(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + (end - start) * animationProgress
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            animationProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }

    private func reorderAssetLive(source: FolderAsset, target: FolderAsset, insertBefore: Bool) {
        var orderedAssets = sortedAssets
        guard let sourceIndex = orderedAssets.firstIndex(where: { $0.id == source.id }),
              let targetIndex = orderedAssets.firstIndex(where: { $0.id == target.id }),
              sourceIndex != targetIndex else {
            return
        }

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

        for (index, photoId) in photoIds.enumerated() {
            let newAsset = FolderAsset(assetIdentifier: photoId, sortOrder: index)
            newAsset.folder = subfolder
            modelContext.insert(newAsset)

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

// MARK: - Overlay Photo Cell
struct OverlayPhotoCell: View {
    let assetIdentifier: String
    let isDragging: Bool
    let dropZone: FolderPhotoDropZone
    @State private var image: UIImage?
    @State private var photoService = PhotoLibraryService.shared

    var body: some View {
        GeometryReader { geo in
            ZStack {
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

                // Drop zone indicators
                if dropZone == .left {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.blue).frame(width: 4)
                        Spacer()
                    }
                } else if dropZone == .right {
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle().fill(Color.blue).frame(width: 4)
                    }
                } else if dropZone == .center {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 3)
                    Color.green.opacity(0.2)
                    Image(systemName: "folder.badge.plus")
                        .font(.title)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDragging ? 0.5 : 1)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .task {
            guard let asset = photoService.fetchAsset(identifier: assetIdentifier) else { return }
            image = await photoService.thumbnail(for: asset, size: CGSize(width: 200, height: 200))
        }
    }
}

// MARK: - Subfolder Stack Card (for inside overlay)
struct SubfolderStackCard: View {
    let folder: Folder
    @State private var images: [UIImage] = []
    @State private var photoService = PhotoLibraryService.shared

    private let rotations: [Double] = [-8, 4, -2]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Stacked images
                ForEach(Array(images.prefix(3).enumerated().reversed()), id: \.offset) { index, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .rotationEffect(.degrees(rotations[safe: index] ?? 0))
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                }

                // Fallback if no images
                if images.isEmpty {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                        .overlay {
                            Image(systemName: "folder.fill")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }

                // Folder label overlay
                VStack {
                    Spacer()
                    Text(folder.name)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .task {
            await loadImages()
        }
    }

    private func loadImages() async {
        let identifiers = folder.allAssetIdentifiers.prefix(3)
        var loaded: [UIImage] = []

        for identifier in identifiers {
            if let asset = photoService.fetchAsset(identifier: identifier),
               let image = await photoService.thumbnail(for: asset, size: CGSize(width: 150, height: 150)) {
                loaded.append(image)
            }
        }

        await MainActor.run {
            images = loaded
        }
    }
}

#Preview {
    FolderOverlayView(folder: Folder(name: "Test"), isPresented: .constant(true), originPoint: CGPoint(x: 100, y: 300))
        .modelContainer(for: [Folder.self, FolderAsset.self], inMemory: true)
}
