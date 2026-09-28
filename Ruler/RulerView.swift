import CoreMotion
import SwiftUI

// iOS exposes no physical PPI. 264ppi@2x iPads, 326ppi@2x phones, ~460ppi@3x phones.
// ponytail: guess by idiom/scale; minis are ~3% off, calibration fixes it. Per-model table if that annoys.
let defaultPtPerMM: Double = (UIDevice.current.userInterfaceIdiom == .pad ? 132
    : UIScreen.main.scale == 2 ? 163 : 153.3) / 25.4

// ISO/IEC 7810 ID-1 (credit card)
let cardShortEdgeMM = 53.98, cardLongEdgeMM = 85.60, cardCornerMM = 3.18

struct RulerView: View {
    @AppStorage("offsetMM") private var offsetMM = 0.0
    @AppStorage("ptPerMM") private var ptPerMM = defaultPtPerMM
    @AppStorage("didCalibrate") private var didCalibrate = false
    @State private var showSettings = false

    var body: some View {
        Canvas { ctx, size in
            // Left edge: mm ticks, cm labels.
            drawTicks(ctx, size: size, ptPerUnit: ptPerMM, offsetUnits: offsetMM, leftEdge: true,
                      length: { $0 % 10 == 0 ? 40 : $0 % 5 == 0 ? 28 : 16 },
                      label: { $0 % 10 == 0 ? "\($0 / 10)" : nil })
            // Right edge: 1/16" ticks, inch labels.
            drawTicks(ctx, size: size, ptPerUnit: ptPerMM * 25.4 / 16, offsetUnits: offsetMM / 25.4 * 16, leftEdge: false,
                      length: { $0 % 16 == 0 ? 40 : $0 % 8 == 0 ? 30 : $0 % 4 == 0 ? 22 : $0 % 2 == 0 ? 15 : 9 },
                      label: { $0 % 16 == 0 ? "\($0 / 16)" : nil })
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            HStack {
                Text("cm").padding(.leading, 80)
                Spacer()
                Text("in").padding(.trailing, 80)
            }
            .padding(.top, 60)
            .font(.headline).foregroundStyle(.secondary)
        }
        .overlay { BubbleLevel() }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if offsetMM > 0 { Text("offset \(offsetMM, specifier: "%.1f") mm").font(.caption).foregroundStyle(.secondary) }
                Button { showSettings = true } label: { Image(systemName: "gearshape").font(.title) }
            }
            .padding(.bottom, 8)
        }
        .onAppear { if !didCalibrate { showSettings = true } } // first launch: calibrate before measuring
        .sheet(isPresented: $showSettings, onDismiss: { didCalibrate = true }) {
            SettingsView(offsetMM: $offsetMM, ptPerMM: $ptPerMM)
                .presentationDetents([.fraction(0.68), .large]) // short enough to keep the ruler visible while calibrating
        }
    }

    // Tick n sits at the true value n; the screen's top edge reads `offsetUnits`.
    private func drawTicks(_ ctx: GraphicsContext, size: CGSize, ptPerUnit: Double, offsetUnits: Double, leftEdge: Bool,
                           length: (Int) -> Double, label: (Int) -> String?) {
        let first = Int(offsetUnits.rounded(.up))
        let last = Int((size.height / ptPerUnit + offsetUnits).rounded(.down))
        for n in stride(from: first, through: last, by: 1) {
            let y = (Double(n) - offsetUnits) * ptPerUnit
            let len = length(n)
            var path = Path()
            path.move(to: CGPoint(x: leftEdge ? 0 : size.width, y: y))
            path.addLine(to: CGPoint(x: leftEdge ? len : size.width - len, y: y))
            ctx.stroke(path, with: .color(.primary), lineWidth: 1)
            if let text = label(n) {
                ctx.draw(Text(text).font(.system(size: 16, weight: .semibold).monospacedDigit()),
                         at: CGPoint(x: leftEdge ? len + 6 : size.width - len - 6, y: y),
                         anchor: leftEdge ? .leading : .trailing)
            }
        }
    }
}

struct SettingsView: View {
    @Binding var offsetMM: Double
    @Binding var ptPerMM: Double
    @AppStorage("didCalibrate") private var didCalibrate = false
    @State private var showCard = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack { form }
    }

    private var form: some View {
        Form {
            if !didCalibrate {
                Section {
                    Text("Every screen is a little different. Calibrate once so the ruler shows true sizes, and set the offset for your case.")
                } header: {
                    Text("Welcome")
                }
            }
            Section {
                Button("Calibrate with a credit card") { showCard = true }
            } header: {
                Text("Calibration")
            } footer: {
                Text("Hold a card against the phone to set both scale and offset.")
            }
            Section {
                PPIStepper(ptPerMM: $ptPerMM)
                OffsetStepper(offsetMM: $offsetMM)
                Button("Reset calibration") {
                    ptPerMM = defaultPtPerMM
                    offsetMM = 0
                }
            } header: {
                Text("Calibrate manually")
            } footer: {
                Text("Scale: match the ruler against a real one. Offset: distance from the phone's physical edge (with case) to where the screen starts. Note both values so you can restore them after a reset.")
            }
        }
        .contentMargins(.bottom, 24, for: .scrollContent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .fullScreenCover(isPresented: $showCard) {
            CardCalibrationView(offsetMM: $offsetMM, ptPerMM: $ptPerMM)
        }
    }
}

let calibrationRange = defaultPtPerMM * 0.85 ... defaultPtPerMM * 1.15

struct OffsetStepper: View {
    @Binding var offsetMM: Double
    var body: some View {
        Stepper("Offset: \(offsetMM, specifier: "%.1f") mm", value: $offsetMM, in: 0...20, step: 0.1)
    }
}

// Shown as physical pixels per inch so the value is easy to write down and re-enter.
struct PPIStepper: View {
    @Binding var ptPerMM: Double
    private let pxPerPt = UIScreen.main.scale
    var body: some View {
        Stepper("Scale: \(ptPerMM * 25.4 * pxPerPt, specifier: "%.1f") ppi", value: $ptPerMM,
                in: calibrationRange, step: 0.5 / (25.4 * pxPerPt))
    }
}

// Card drawn upright, its top edge at the phone's physical top edge (offset above the screen).
// Width depends only on scale; bottom edge depends on scale + offset. So: width first, then bottom.
struct CardCalibrationView: View {
    @Binding var offsetMM: Double
    @Binding var ptPerMM: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardCornerMM * ptPerMM)
                .fill(.tint.opacity(0.15))
                .stroke(.tint, lineWidth: 2)
                .frame(width: cardShortEdgeMM * ptPerMM, height: cardLongEdgeMM * ptPerMM)
                .offset(y: -offsetMM * ptPerMM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .statusBarHidden()
        // ponytail: on short screens (iPhone SE) the controls cover the card's bottom edge; drag-to-adjust if that matters.
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                Text("Hold a card upright, flush with the top edge of the phone.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("1. Width").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                PPIStepper(ptPerMM: $ptPerMM)
                Text("2. Bottom edge").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                OffsetStepper(offsetMM: $offsetMM)
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        }
    }
}

@Observable final class Tilt {
    var gravity = CMAcceleration(x: 0, y: 0, z: -1)
    private let motion = CMMotionManager()

    func start() {
        guard motion.isDeviceMotionAvailable else { return } // simulator: bubble stays centered
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            if let g = m?.gravity { self?.gravity = g }
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }
}

// Flat-surface level: the bubble floats away from the low side.
struct BubbleLevel: View {
    @State private var tilt = Tilt()
    private let radius = 70.0

    var body: some View {
        let g = tilt.gravity
        let degrees = acos(min(1, -g.z)) * 180 / .pi
        let gain = 4.0 // ~15° tilt reaches the ring
        let scale = gain / max(1, hypot(g.x, g.y) * gain) // keep the bubble inside the ring
        let level = degrees < 1
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(.secondary, lineWidth: 2)
                Circle().stroke(.secondary.opacity(0.5), lineWidth: 1).frame(width: 34, height: 34)
                Circle()
                    .fill(level ? .green : .orange)
                    .frame(width: 30, height: 30)
                    .offset(x: -g.x * radius * scale, y: g.y * radius * scale)
                    .animation(.easeOut(duration: 0.1), value: g.x)
            }
            .frame(width: radius * 2 + 30, height: radius * 2 + 30)
            Text("\(degrees, specifier: "%.1f")°").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }
}
