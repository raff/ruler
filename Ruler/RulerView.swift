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
    @AppStorage("bottomOffsetMM") private var bottomOffsetMM = 0.0
    @AppStorage("reversed") private var reversed = false
    @AppStorage("ptPerMM") private var ptPerMM = defaultPtPerMM
    @AppStorage("didCalibrate") private var didCalibrate = false
    @State private var showSettings = false

    var body: some View {
        let activeOffsetMM = reversed ? bottomOffsetMM : offsetMM
        Canvas { ctx, size in
            // Left edge: mm ticks, cm labels.
            drawTicks(ctx, size: size, ptPerUnit: ptPerMM, offsetUnits: activeOffsetMM, leftEdge: true,
                      length: { $0 % 10 == 0 ? 40 : $0 % 5 == 0 ? 28 : 16 },
                      label: { $0 % 10 == 0 ? "\($0 / 10)" : nil })
            // Right edge: 1/16" ticks, inch labels.
            drawTicks(ctx, size: size, ptPerUnit: ptPerMM * 25.4 / 16, offsetUnits: activeOffsetMM / 25.4 * 16, leftEdge: false,
                      length: { $0 % 16 == 0 ? 40 : $0 % 8 == 0 ? 30 : $0 % 4 == 0 ? 22 : $0 % 2 == 0 ? 15 : 9 },
                      label: { $0 % 16 == 0 ? "\($0 / 16)" : nil })
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .background(Color(.systemBackground))
        .animation(nil, value: reversed)
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
                if activeOffsetMM > 0 { Text("\(reversed ? "bottom " : "")offset \(activeOffsetMM, specifier: "%.1f") mm").font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 32) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape").font(.title) }
                    Button { reversed.toggle() } label: {
                        Image(systemName: "arrow.up.arrow.down.square\(reversed ? ".fill" : "")").font(.title)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .onAppear { if !didCalibrate { showSettings = true } } // first launch: calibrate before measuring
        .sheet(isPresented: $showSettings, onDismiss: { didCalibrate = true }) {
            SettingsView(offsetMM: $offsetMM, bottomOffsetMM: $bottomOffsetMM, reversed: $reversed, ptPerMM: $ptPerMM)
                .presentationDetents([.fraction(0.68), .large]) // short enough to keep the ruler visible while calibrating
        }
    }

    // Tick n sits at the true value n; the screen's top edge (bottom edge when reversed) reads `offsetUnits`.
    private func drawTicks(_ ctx: GraphicsContext, size: CGSize, ptPerUnit: Double, offsetUnits: Double, leftEdge: Bool,
                           length: (Int) -> Double, label: (Int) -> String?) {
        let first = Int(offsetUnits.rounded(.up))
        let last = Int((size.height / ptPerUnit + offsetUnits).rounded(.down))
        for n in stride(from: first, through: last, by: 1) {
            let dist = (Double(n) - offsetUnits) * ptPerUnit
            let y = reversed ? size.height - dist : dist
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
    @Binding var bottomOffsetMM: Double
    @Binding var reversed: Bool
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
                Toggle("Zero at the bottom", isOn: $reversed)
            } footer: {
                Text("Reverse the scales so 0 is at the bottom edge. Lay the phone flat next to the object and read the size at the top.")
            }
            Section {
                Button("Calibrate with a credit card") { showCard = true }
            } header: {
                Text("Calibration")
            } footer: {
                Text("Hold a card against the \(reversed ? "bottom" : "top") of the phone to set both scale and \(reversed ? "bottom " : "")offset.")
            }
            Section {
                PPIStepper(ptPerMM: $ptPerMM)
                OffsetStepper(title: "Top offset", offsetMM: $offsetMM)
                OffsetStepper(title: "Bottom offset", offsetMM: $bottomOffsetMM)
                Button("Reset calibration") {
                    ptPerMM = defaultPtPerMM
                    offsetMM = 0
                    bottomOffsetMM = 0
                }
            } header: {
                Text("Calibrate manually")
            } footer: {
                Text("Scale: match the ruler against a real one. Offset: distance from the phone's physical edge (with case) to where the screen starts, measured separately for the top and bottom edge. Note both values so you can restore them after a reset.")
            }
        }
        .contentMargins(.bottom, 24, for: .scrollContent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .fullScreenCover(isPresented: $showCard) {
            CardCalibrationView(offsetMM: reversed ? $bottomOffsetMM : $offsetMM, reversed: reversed, ptPerMM: $ptPerMM)
        }
    }
}

let calibrationRange = defaultPtPerMM * 0.85 ... defaultPtPerMM * 1.15

struct OffsetStepper: View {
    var title = "Offset"
    @Binding var offsetMM: Double
    var body: some View {
        Stepper("\(title): \(offsetMM, specifier: "%.1f") mm", value: $offsetMM, in: 0...20, step: 0.1)
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

// Card drawn upright, its top edge at the phone's physical top edge (offset above the screen);
// when reversed, its bottom edge at the physical bottom edge instead.
// Width depends only on scale; the far edge depends on scale + offset. So: width first, then that edge.
struct CardCalibrationView: View {
    @Binding var offsetMM: Double
    var reversed = false
    @Binding var ptPerMM: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: reversed ? .bottom : .top) {
            RoundedRectangle(cornerRadius: cardCornerMM * ptPerMM)
                .fill(.tint.opacity(0.15))
                .stroke(.tint, lineWidth: 2)
                .frame(width: cardShortEdgeMM * ptPerMM, height: cardLongEdgeMM * ptPerMM)
                .offset(y: (reversed ? 1 : -1) * offsetMM * ptPerMM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: reversed ? .bottom : .top)
        .ignoresSafeArea()
        .statusBarHidden()
        // ponytail: on short screens (iPhone SE) the controls cover the card's bottom edge; drag-to-adjust if that matters.
        .overlay(alignment: reversed ? .top : .bottom) {
            VStack(spacing: 12) {
                Text("Hold a card upright, flush with the \(reversed ? "bottom" : "top") edge of the phone.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("1. Width").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                PPIStepper(ptPerMM: $ptPerMM)
                Text("2. \(reversed ? "Top" : "Bottom") edge").font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                OffsetStepper(title: reversed ? "Bottom offset" : "Top offset", offsetMM: $offsetMM)
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
// Phone on its side (screen upright): a tube along whichever screen axis is closer to horizontal.
struct BubbleLevel: View {
    @State private var tilt = Tilt()
    private let radius = 70.0

    var body: some View {
        let g = tilt.gravity
        let upright = abs(g.z) < 0.7
        let alongX = abs(g.x) < abs(g.y) // gravity mostly along y: level line runs along x
        let gain = 4.0 // ~15° tilt reaches the ring
        let scale = gain / max(1, hypot(g.x, g.y) * gain) // keep the bubble inside the ring
        let degrees = upright ? asin(min(1, abs(alongX ? g.x : g.y))) * 180 / .pi
                              : acos(min(1, -g.z)) * 180 / .pi
        let level = degrees < 1
        let dx = upright ? (alongX ? -g.x * radius * gain : 0) : -g.x * radius * scale
        let dy = upright ? (alongX ? 0 : g.y * radius * gain) : g.y * radius * scale
        let limit = radius // tube half-length
        VStack(spacing: 10) {
            ZStack {
                if upright {
                    Capsule().stroke(.secondary, lineWidth: 2)
                        .frame(width: alongX ? limit * 2 + 30 : 44, height: alongX ? 44 : limit * 2 + 30)
                    Capsule().stroke(.secondary.opacity(0.5), lineWidth: 1)
                        .frame(width: alongX ? 34 : 44, height: alongX ? 44 : 34)
                } else {
                    Circle().stroke(.secondary, lineWidth: 2)
                    Circle().stroke(.secondary.opacity(0.5), lineWidth: 1).frame(width: 34, height: 34)
                }
                Circle()
                    .fill(level ? .green : .orange)
                    .frame(width: 30, height: 30)
                    .offset(x: upright ? max(-limit, min(limit, dx)) : dx, y: upright ? max(-limit, min(limit, dy)) : dy)
                    .animation(.easeOut(duration: 0.1), value: g.x + g.y)
            }
            .frame(width: radius * 2 + 30, height: radius * 2 + 30)
            Text("\(degrees, specifier: "%.1f")°").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .onAppear { tilt.start() }
        .onDisappear { tilt.stop() }
    }
}
