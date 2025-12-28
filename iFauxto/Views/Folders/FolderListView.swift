import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    @State private var showingNewFolder = false
    @State private var currentSort: FolderSortOption = .custom
    @State private var folderToDelete: Folder?
    @State private var showingDeleteConfirmation = false
    @State private var draggingFolder: Folder?
    @State private var selectedFolder: Folder?
    @State private var folderOrigin: CGPoint = .zero
    @State private var folderPositions: [UUID: CGPoint] = [:]

    private var userPreferences: UserPreferences? {
        preferences.first
    }

    private var sortedFolders: [Folder] {
        switch currentSort {
        case .custom:
            return folders.sorted { $0.sortOrder < $1.sortOrder }
        case .alphabetical:
            return folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostRecent:
            return folders.sorted { $0.updatedAt > $1.updatedAt }
        case .chronological:
            return folders.sorted { $0.createdAt < $1.createdAt }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        Group {
            if folders.isEmpty {
                emptyState
            } else {
                folderGrid
            }
        }
        .navigationTitle("All Folders")
        .onAppear {
            if let prefs = userPreferences {
                currentSort = prefs.folderSort
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                sortMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingNewFolder) {
            FolderEditSheet(mode: .create) { name in
                createFolder(name: name)
            }
        }
        .alert("Delete Folder?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    modelContext.delete(folder)
                    triggerHaptic()
                }
                folderToDelete = nil
            }
        } message: {
            if let folder = folderToDelete {
                Text("Are you sure you want to delete \"\(folder.name)\"? This cannot be undone.")
            }
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Folders Yet", systemImage: "folder")
        } description: {
            Text("Unlike Apple, we won't auto-create 47 albums you didn't ask for.\nTap + to create your first folder.")
        } actions: {
            Button {
                showingNewFolder = true
            } label: {
                Text("Create Folder")
            }
        }
    }

    private var folderGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedFolders, id: \.id) { folder in
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
                                .frame(width: 150, height: 150)
                                .onAppear {
                                    draggingFolder = folder
                                }
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
                        } isTargeted: { isTargeted in
                            // Visual feedback when targeted
                        }
                        .contextMenu {
                            Button {
                                folder.isFavorite.toggle()
                                triggerHaptic()
                            } label: {
                                Label(
                                    folder.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: folder.isFavorite ? "heart.slash" : "heart"
                                )
                            }

                            Divider()

                            Button(role: .destructive) {
                                folderToDelete = folder
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(20)
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggingFolder = nil
            return false
        }
    }

    private func reorderFolder(source: Folder, target: Folder) {
        // Switch to custom sort when reordering
        if currentSort != .custom {
            currentSort = .custom
            userPreferences?.folderSort = .custom
        }

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

    private var sortMenu: some View {
        Menu {
            ForEach(FolderSortOption.allCases) { option in
                Button {
                    withAnimation {
                        currentSort = option
                        userPreferences?.folderSort = option
                    }
                } label: {
                    HStack {
                        Image(systemName: option.systemImage)
                        Text(option.rawValue)
                        if currentSort == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private func createFolder(name: String) {
        let maxSortOrder = folders.map(\.sortOrder).max() ?? -1
        let folder = Folder(name: name, sortOrder: maxSortOrder + 1)
        modelContext.insert(folder)
        triggerHaptic()
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    NavigationStack {
        FolderListView()
    }
    .modelContainer(for: [Folder.self, UserPreferences.self], inMemory: true)
}
