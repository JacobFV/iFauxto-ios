import SwiftUI
import Photos

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset
    let folder: Folder?

    @State private var photoService = PhotoLibraryService.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var showingEditor = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(magnificationGesture)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        if let date = asset.creationDate {
                            Text(date, style: .date)
                                .font(.caption)
                            Text(date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEditor = true
                    } label: {
                        Text("Edit")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task {
                await loadFullImage()
            }
            .fullScreenCover(isPresented: $showingEditor) {
                if let image {
                    PhotoEditorView(originalImage: image, asset: asset)
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 4)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.0 {
                    withAnimation(.spring()) {
                        scale = 1.0
                    }
                }
            }
    }

    private func loadFullImage() async {
        image = await photoService.fullSizeImage(for: asset)
        isLoading = false
    }
}

#Preview {
    Text("PhotoDetailView requires real PHAsset")
}
