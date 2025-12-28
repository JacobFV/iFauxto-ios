import SwiftUI

struct PresetsControl: View {
    @Bindable var processor: ImageProcessor
    let onSelect: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button {
                    processor.reset()
                    onSelect()
                } label: {
                    VStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.white)
                            }
                        Text("Reset")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }

                ForEach(EditPreset.builtIn) { preset in
                    Button {
                        processor.applyPreset(preset)
                        onSelect()
                    } label: {
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Text(String(preset.name.prefix(2)))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            Text(preset.snarkyName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct LightControls: View {
    @Bindable var processor: ImageProcessor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AdjustmentSlider(
                    title: "Exposure",
                    value: $processor.exposure,
                    range: -2...2,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Contrast",
                    value: $processor.contrast,
                    range: 0.5...1.5,
                    defaultValue: 1
                )

                AdjustmentSlider(
                    title: "Brightness",
                    value: $processor.brightness,
                    range: -0.5...0.5,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Highlights",
                    value: $processor.highlights,
                    range: 0...1.5,
                    defaultValue: 1
                )

                AdjustmentSlider(
                    title: "Shadows",
                    value: $processor.shadows,
                    range: -1...1,
                    defaultValue: 0
                )
            }
            .padding(.vertical)
        }
    }
}

struct ColorControls: View {
    @Bindable var processor: ImageProcessor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AdjustmentSlider(
                    title: "Temperature",
                    value: $processor.temperature,
                    range: 3000...9000,
                    defaultValue: 6500
                )

                AdjustmentSlider(
                    title: "Tint",
                    value: $processor.tint,
                    range: -100...100,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Saturation",
                    value: $processor.saturation,
                    range: 0...2,
                    defaultValue: 1
                )

                AdjustmentSlider(
                    title: "Vibrance",
                    value: $processor.vibrance,
                    range: -1...1,
                    defaultValue: 0
                )
            }
            .padding(.vertical)
        }
    }
}

struct EffectsControls: View {
    @Bindable var processor: ImageProcessor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AdjustmentSlider(
                    title: "Fade",
                    value: $processor.fade,
                    range: 0...1,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Grain",
                    value: $processor.grain,
                    range: 0...1,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Vignette",
                    value: $processor.vignette,
                    range: 0...1,
                    defaultValue: 0
                )

                AdjustmentSlider(
                    title: "Sharpness",
                    value: $processor.sharpness,
                    range: 0...2,
                    defaultValue: 0
                )
            }
            .padding(.vertical)
        }
    }
}

struct HSLControls: View {
    @Bindable var processor: ImageProcessor
    @State private var selectedChannel: HSLChannel = .red

    var body: some View {
        VStack(spacing: 12) {
            Picker("Channel", selection: $selectedChannel) {
                ForEach(HSLChannel.allCases, id: \.self) { channel in
                    Text(channel.rawValue)
                        .tag(channel)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    AdjustmentSlider(
                        title: "Hue",
                        value: hueBinding,
                        range: -180...180,
                        defaultValue: 0
                    )

                    AdjustmentSlider(
                        title: "Saturation",
                        value: saturationBinding,
                        range: 0...2,
                        defaultValue: 1
                    )

                    AdjustmentSlider(
                        title: "Luminance",
                        value: luminanceBinding,
                        range: -1...1,
                        defaultValue: 0
                    )
                }
                .padding(.vertical)
            }
        }
    }

    private var hueBinding: Binding<Double> {
        switch selectedChannel {
        case .red: return $processor.hueRed
        case .orange: return $processor.hueOrange
        case .yellow: return $processor.hueYellow
        case .green: return $processor.hueGreen
        case .blue: return $processor.hueBlue
        case .purple: return $processor.huePurple
        }
    }

    private var saturationBinding: Binding<Double> {
        switch selectedChannel {
        case .red: return $processor.saturationRed
        case .orange: return $processor.saturationOrange
        case .yellow: return $processor.saturationYellow
        case .green: return $processor.saturationGreen
        case .blue: return $processor.saturationBlue
        case .purple: return $processor.saturationPurple
        }
    }

    private var luminanceBinding: Binding<Double> {
        switch selectedChannel {
        case .red: return $processor.luminanceRed
        case .orange: return $processor.luminanceOrange
        case .yellow: return $processor.luminanceYellow
        case .green: return $processor.luminanceGreen
        case .blue: return $processor.luminanceBlue
        case .purple: return $processor.luminancePurple
        }
    }
}

enum HSLChannel: String, CaseIterable {
    case red = "R"
    case orange = "O"
    case yellow = "Y"
    case green = "G"
    case blue = "B"
    case purple = "P"
}

struct TransformControls: View {
    @Bindable var processor: ImageProcessor
    let onTransform: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                Button {
                    processor.rotation -= 90
                    if processor.rotation <= -360 { processor.rotation = 0 }
                    onTransform()
                } label: {
                    VStack {
                        Image(systemName: "rotate.left")
                            .font(.title2)
                        Text("Rotate L")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }

                Button {
                    processor.rotation += 90
                    if processor.rotation >= 360 { processor.rotation = 0 }
                    onTransform()
                } label: {
                    VStack {
                        Image(systemName: "rotate.right")
                            .font(.title2)
                        Text("Rotate R")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }

                Button {
                    processor.flipHorizontal.toggle()
                    onTransform()
                } label: {
                    VStack {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .font(.title2)
                        Text("Flip H")
                            .font(.caption2)
                    }
                    .foregroundStyle(processor.flipHorizontal ? .blue : .white)
                }

                Button {
                    processor.flipVertical.toggle()
                    onTransform()
                } label: {
                    VStack {
                        Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                            .font(.title2)
                        Text("Flip V")
                            .font(.caption2)
                    }
                    .foregroundStyle(processor.flipVertical ? .blue : .white)
                }
            }

            Text("Crop coming soon. Unlike Apple, we won't make you wait 3 iOS versions for basic features.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    VStack {
        LightControls(processor: ImageProcessor())
    }
    .background(Color.black)
}
