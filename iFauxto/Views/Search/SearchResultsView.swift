import SwiftUI
import SwiftData
import Photos

struct SearchResultsView: View {
    let searchText: String

    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [AssetTag]
    @Query private var allFolders: [Folder]
    @State private var photoService = PhotoLibraryService.shared
    @State private var selectedAsset: PHAsset?

    private var matchingTags: [AssetTag] {
        guard !searchText.isEmpty else { return [] }
        let lowercased = searchText.lowercased()
        return allTags.filter { $0.value.lowercased().contains(lowercased) }
    }

    private var matchingFolders: [Folder] {
        guard !searchText.isEmpty else { return [] }
        let lowercased = searchText.lowercased()
        return allFolders.filter { $0.name.lowercased().contains(lowercased) }
    }

    private var uniqueAssetIdentifiers: [String] {
        Array(Set(matchingTags.map(\.assetIdentifier)))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !matchingFolders.isEmpty {
                    folderSection
                }

                if !uniqueAssetIdentifiers.isEmpty {
                    photoSection
                }

                if matchingFolders.isEmpty && uniqueAssetIdentifiers.isEmpty && !searchText.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .sheet(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset, folder: nil)
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folders")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(matchingFolders) { folder in
                NavigationLink {
                    FolderDetailView(folder: folder)
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(folder.name)
                        Spacer()
                        Text("\(folder.safeAssets.count)")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photos")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(uniqueAssetIdentifiers.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(uniqueAssetIdentifiers, id: \.self) { identifier in
                    PhotoThumbnail(assetIdentifier: identifier)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let asset = photoService.fetchAsset(identifier: identifier) {
                                selectedAsset = asset
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No results for \"\(searchText)\"")
                .font(.headline)

            Text("Try different keywords, or let our AI tag more of your photos in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

#Preview {
    NavigationStack {
        SearchResultsView(searchText: "test")
    }
    .modelContainer(for: [AssetTag.self, Folder.self], inMemory: true)
}
