import SwiftUI

struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, defaultValue: Double = 0) {
        self.title = title
        self._value = value
        self.range = range
        self.defaultValue = defaultValue
    }

    private var isModified: Bool {
        abs(value - defaultValue) > 0.001
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white)

                Spacer()

                Text(formattedValue)
                    .font(.caption)
                    .foregroundStyle(isModified ? .blue : .secondary)
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            value = defaultValue
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                    let normalizedDefault = (defaultValue - range.lowerBound) / (range.upperBound - range.lowerBound)

                    if defaultValue != range.lowerBound {
                        let start = min(normalizedValue, normalizedDefault)
                        let width = abs(normalizedValue - normalizedDefault)

                        Capsule()
                            .fill(Color.blue)
                            .frame(width: max(0, width * geometry.size.width), height: 4)
                            .offset(x: start * geometry.size.width)
                    } else {
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: normalizedValue * geometry.size.width, height: 4)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .offset(x: normalizedValue * (geometry.size.width - 20))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let newValue = gesture.location.x / geometry.size.width
                                    let clamped = min(max(newValue, 0), 1)
                                    value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                                }
                        )
                }
                .frame(height: 20)
            }
            .frame(height: 20)
        }
        .padding(.horizontal)
    }

    private var formattedValue: String {
        if range.upperBound <= 2 && range.lowerBound >= -2 {
            let percentage = (value - defaultValue) * 100
            if abs(percentage) < 0.5 {
                return "0"
            }
            return String(format: "%+.0f", percentage)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

#Preview {
    @Previewable @State var value: Double = 0.5

    VStack {
        AdjustmentSlider(
            title: "Exposure",
            value: $value,
            range: -2...2,
            defaultValue: 0
        )
    }
    .padding()
    .background(Color.black)
}
