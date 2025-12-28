import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@Observable
final class ImageProcessor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    var exposure: Double = 0
    var contrast: Double = 1
    var brightness: Double = 0
    var highlights: Double = 1
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0

    var temperature: Double = 6500
    var tint: Double = 0
    var saturation: Double = 1
    var vibrance: Double = 0

    var hueRed: Double = 0
    var hueOrange: Double = 0
    var hueYellow: Double = 0
    var hueGreen: Double = 0
    var hueBlue: Double = 0
    var huePurple: Double = 0

    var saturationRed: Double = 1
    var saturationOrange: Double = 1
    var saturationYellow: Double = 1
    var saturationGreen: Double = 1
    var saturationBlue: Double = 1
    var saturationPurple: Double = 1

    var luminanceRed: Double = 0
    var luminanceOrange: Double = 0
    var luminanceYellow: Double = 0
    var luminanceGreen: Double = 0
    var luminanceBlue: Double = 0
    var luminancePurple: Double = 0

    var fade: Double = 0
    var grain: Double = 0
    var vignette: Double = 0
    var sharpness: Double = 0

    var highlightsTint: CIColor = CIColor(red: 1, green: 1, blue: 1)
    var shadowsTint: CIColor = CIColor(red: 0, green: 0, blue: 0)
    var splitToneBalance: Double = 0

    var cropRect: CGRect?
    var rotation: Double = 0
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false

    func process(_ image: CIImage) -> CIImage {
        var output = image

        output = applyExposure(to: output)
        output = applyColorControls(to: output)
        output = applyHighlightsShadows(to: output)
        output = applyTemperatureTint(to: output)
        output = applyVibrance(to: output)
        output = applyFade(to: output)
        output = applyVignette(to: output)
        output = applySharpness(to: output)
        output = applyGrain(to: output)
        output = applyTransform(to: output)

        return output
    }

    private func applyExposure(to image: CIImage) -> CIImage {
        guard exposure != 0 else { return image }

        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(exposure)
        return filter.outputImage ?? image
    }

    private func applyColorControls(to image: CIImage) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = Float(saturation)
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        return filter.outputImage ?? image
    }

    private func applyHighlightsShadows(to image: CIImage) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = Float(highlights)
        filter.shadowAmount = Float(shadows)
        return filter.outputImage ?? image
    }

    private func applyTemperatureTint(to image: CIImage) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: CGFloat(temperature), y: CGFloat(tint))
        filter.targetNeutral = CIVector(x: 6500, y: 0)
        return filter.outputImage ?? image
    }

    private func applyVibrance(to image: CIImage) -> CIImage {
        guard vibrance != 0 else { return image }

        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = Float(vibrance)
        return filter.outputImage ?? image
    }

    private func applyFade(to image: CIImage) -> CIImage {
        guard fade > 0 else { return image }

        let filter = CIFilter.photoEffectFade()
        filter.inputImage = image

        guard let fadedImage = filter.outputImage else { return image }

        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = fadedImage.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(fade))
        ])
        blendFilter.backgroundImage = image
        return blendFilter.outputImage ?? image
    }

    private func applyVignette(to image: CIImage) -> CIImage {
        guard vignette > 0 else { return image }

        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = Float(vignette * 2)
        filter.radius = Float(2)
        return filter.outputImage ?? image
    }

    private func applySharpness(to image: CIImage) -> CIImage {
        guard sharpness != 0 else { return image }

        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = Float(sharpness)
        return filter.outputImage ?? image
    }

    private func applyGrain(to image: CIImage) -> CIImage {
        guard grain > 0 else { return image }

        let noiseFilter = CIFilter.randomGenerator()
        guard let noiseImage = noiseFilter.outputImage else { return image }

        let grainImage = noiseImage
            .cropped(to: image.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(grain * 0.1))
            ])

        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = grainImage
        blendFilter.backgroundImage = image
        return blendFilter.outputImage ?? image
    }

    private func applyTransform(to image: CIImage) -> CIImage {
        var output = image

        if rotation != 0 {
            let radians = rotation * .pi / 180
            output = output.transformed(by: CGAffineTransform(rotationAngle: CGFloat(radians)))
        }

        if flipHorizontal {
            output = output.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }

        if flipVertical {
            output = output.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        }

        if let crop = cropRect {
            output = output.cropped(to: crop)
        }

        return output
    }

    func renderToUIImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    func reset() {
        exposure = 0
        contrast = 1
        brightness = 0
        highlights = 1
        shadows = 0
        whites = 0
        blacks = 0

        temperature = 6500
        tint = 0
        saturation = 1
        vibrance = 0

        hueRed = 0
        hueOrange = 0
        hueYellow = 0
        hueGreen = 0
        hueBlue = 0
        huePurple = 0

        saturationRed = 1
        saturationOrange = 1
        saturationYellow = 1
        saturationGreen = 1
        saturationBlue = 1
        saturationPurple = 1

        luminanceRed = 0
        luminanceOrange = 0
        luminanceYellow = 0
        luminanceGreen = 0
        luminanceBlue = 0
        luminancePurple = 0

        fade = 0
        grain = 0
        vignette = 0
        sharpness = 0

        cropRect = nil
        rotation = 0
        flipHorizontal = false
        flipVertical = false
    }

    func applyPreset(_ preset: EditPreset) {
        exposure = preset.exposure
        contrast = preset.contrast
        brightness = preset.brightness
        saturation = preset.saturation
        temperature = preset.temperature
        fade = preset.fade
        grain = preset.grain
        vignette = preset.vignette
    }
}

struct EditPreset: Identifiable {
    let id = UUID()
    let name: String
    let snarkyName: String
    let exposure: Double
    let contrast: Double
    let brightness: Double
    let saturation: Double
    let temperature: Double
    let fade: Double
    let grain: Double
    let vignette: Double

    static let builtIn: [EditPreset] = [
        EditPreset(
            name: "Clean",
            snarkyName: "Actually Good Auto",
            exposure: 0.1,
            contrast: 1.05,
            brightness: 0.02,
            saturation: 1.05,
            temperature: 6500,
            fade: 0,
            grain: 0,
            vignette: 0
        ),
        EditPreset(
            name: "Film",
            snarkyName: "Hipster Approved",
            exposure: 0.05,
            contrast: 0.95,
            brightness: 0,
            saturation: 0.9,
            temperature: 6800,
            fade: 0.2,
            grain: 0.3,
            vignette: 0.1
        ),
        EditPreset(
            name: "Moody",
            snarkyName: "Instagram Influencer",
            exposure: -0.1,
            contrast: 1.1,
            brightness: -0.05,
            saturation: 0.85,
            temperature: 6200,
            fade: 0.1,
            grain: 0.1,
            vignette: 0.2
        ),
        EditPreset(
            name: "Vibrant",
            snarkyName: "HDR But Actually Good",
            exposure: 0.1,
            contrast: 1.15,
            brightness: 0.05,
            saturation: 1.25,
            temperature: 6500,
            fade: 0,
            grain: 0,
            vignette: 0
        ),
        EditPreset(
            name: "B&W",
            snarkyName: "Artsy Fartsy",
            exposure: 0.1,
            contrast: 1.2,
            brightness: 0,
            saturation: 0,
            temperature: 6500,
            fade: 0,
            grain: 0.2,
            vignette: 0.15
        ),
        EditPreset(
            name: "Warm",
            snarkyName: "Golden Hour Faker",
            exposure: 0.05,
            contrast: 1.05,
            brightness: 0.02,
            saturation: 1.1,
            temperature: 7200,
            fade: 0,
            grain: 0,
            vignette: 0.05
        ),
        EditPreset(
            name: "Cool",
            snarkyName: "Winter Wonderland",
            exposure: 0,
            contrast: 1.05,
            brightness: 0,
            saturation: 0.95,
            temperature: 5800,
            fade: 0,
            grain: 0,
            vignette: 0
        ),
        EditPreset(
            name: "Faded",
            snarkyName: "Vintage Vibes",
            exposure: 0.1,
            contrast: 0.9,
            brightness: 0.05,
            saturation: 0.8,
            temperature: 6600,
            fade: 0.35,
            grain: 0.15,
            vignette: 0.1
        )
    ]
}
