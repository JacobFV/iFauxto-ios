import SwiftUI
import Photos

struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let originalImage: UIImage
    let asset: PHAsset

    @State private var processor = ImageProcessor()
    @State private var processedImage: UIImage?
    @State private var selectedTool: EditorTool = .presets
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var updateTrigger = false

    private var ciImage: CIImage? {
        guard let cgImage = originalImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    var body: some View {
        NavigationStack {
            editorContent
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            imagePreview
                .frame(maxHeight: .infinity)

            toolSelector

            currentToolControls
                .frame(height: 180)
                .padding(.bottom)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { editorToolbar }
        .onAppear { updatePreview() }
        .onChange(of: updateTrigger) { updatePreview() }
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("Nice") { dismiss() }
        } message: {
            Text("Your masterpiece has been saved. Unlike some apps, we put it exactly where you'd expect.")
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.white)
        }

        ToolbarItem(placement: .principal) {
            Text(selectedTool.rawValue)
                .font(.headline)
                .foregroundStyle(.white)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                saveImage()
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save")
                        .foregroundStyle(.white)
                }
            }
            .disabled(isSaving)
        }
    }

    private var imagePreview: some View {
        GeometryReader { geometry in
            if let image = processedImage ?? originalImage as UIImage? {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var toolSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.icon)
                                .font(.title2)
                            Text(tool.rawValue)
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedTool == tool ? .blue : .white)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.8))
    }

    @ViewBuilder
    private var currentToolControls: some View {
        switch selectedTool {
        case .presets:
            PresetsControl(processor: processor) { triggerUpdate() }
        case .light:
            LightControls(processor: processor)
                .onChange(of: processor.exposure) { triggerUpdate() }
                .onChange(of: processor.contrast) { triggerUpdate() }
                .onChange(of: processor.brightness) { triggerUpdate() }
                .onChange(of: processor.highlights) { triggerUpdate() }
                .onChange(of: processor.shadows) { triggerUpdate() }
        case .color:
            ColorControls(processor: processor)
                .onChange(of: processor.saturation) { triggerUpdate() }
                .onChange(of: processor.temperature) { triggerUpdate() }
                .onChange(of: processor.tint) { triggerUpdate() }
                .onChange(of: processor.vibrance) { triggerUpdate() }
        case .effects:
            EffectsControls(processor: processor)
                .onChange(of: processor.fade) { triggerUpdate() }
                .onChange(of: processor.grain) { triggerUpdate() }
                .onChange(of: processor.vignette) { triggerUpdate() }
                .onChange(of: processor.sharpness) { triggerUpdate() }
        case .hsl:
            HSLControls(processor: processor)
        case .transform:
            TransformControls(processor: processor) { triggerUpdate() }
        }
    }

    private func triggerUpdate() {
        updateTrigger.toggle()
    }

    private func updatePreview() {
        guard let ci = ciImage else { return }
        let processed = processor.process(ci)
        processedImage = processor.renderToUIImage(processed)
    }

    private func saveImage() {
        guard let ci = ciImage else { return }
        isSaving = true

        Task {
            let processed = processor.process(ci)
            guard let finalImage = processor.renderToUIImage(processed) else {
                await MainActor.run { isSaving = false }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    isSaving = false
                    if success {
                        showingSaveSuccess = true
                    }
                }
            }
        }
    }
}

enum EditorTool: String, CaseIterable {
    case presets = "Presets"
    case light = "Light"
    case color = "Color"
    case effects = "Effects"
    case hsl = "HSL"
    case transform = "Transform"

    var icon: String {
        switch self {
        case .presets: return "wand.and.stars"
        case .light: return "sun.max"
        case .color: return "paintpalette"
        case .effects: return "sparkles"
        case .hsl: return "slider.horizontal.3"
        case .transform: return "crop.rotate"
        }
    }
}

#Preview {
    PhotoEditorView(
        originalImage: UIImage(systemName: "photo")!,
        asset: PHAsset()
    )
}
