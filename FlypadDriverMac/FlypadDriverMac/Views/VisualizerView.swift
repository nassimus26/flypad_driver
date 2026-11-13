import SwiftUI

public struct VisualizerView: View {
    @ObservedObject var viewModel: VisualizerViewModel

    public init(viewModel: VisualizerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection Status Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flypad Telemetry & Controller Visualizer")
                            .font(.title2)
                            .bold()
                        Text("Live visual input representation and hardware connection status.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    StatusBadgeView(state: viewModel.connectionState)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Header Metrics
                HStack(spacing: 24) {
                    MetricCard(title: "Packet Rate", value: "\(viewModel.packetsPerSecond) Hz", icon: "waveform.path.ecg")
                    MetricCard(title: "Battery Level", value: viewModel.rawTelemetry.batteryLevel >= 0 ? "\(viewModel.rawTelemetry.batteryLevel)%" : "N/A", icon: "battery.100")
                    MetricCard(title: "Virtual Controller", value: viewModel.virtualControllerConnected ? "Active" : "Inactive", icon: "gamecontroller", valueColor: viewModel.virtualControllerConnected ? .green : .red)
                }

                // Invert Top/Bottom Checkboxes Quick Controls
                HStack(spacing: 32) {
                    Toggle("Invert Left Y (Top ↔ Bottom)", isOn: Binding(
                        get: { viewModel.profile.axisMappings[.pitch]?.isInverted ?? false },
                        set: { _ in viewModel.toggleInvertLeftY() }
                    ))
                    .toggleStyle(.checkbox)

                    Toggle("Invert Right Y (Top ↔ Bottom)", isOn: Binding(
                        get: { viewModel.profile.axisMappings[.gaz]?.isInverted ?? false },
                        set: { _ in viewModel.toggleInvertRightY() }
                    ))
                    .toggleStyle(.checkbox)

                    Spacer()
                }
                .padding(.horizontal, 4)

                // Live Stick Visualizers
                HStack(spacing: 30) {
                    StickVisualizerCard(
                        title: "Left Thumbstick (Roll / Pitch)",
                        x: viewModel.mappedState.leftStickX,
                        y: viewModel.mappedState.leftStickY
                    )

                    StickVisualizerCard(
                        title: "Right Thumbstick (Yaw / Gaz)",
                        x: viewModel.mappedState.rightStickX,
                        y: viewModel.mappedState.rightStickY
                    )
                }

                // Triggers & Shoulders
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trigger & Shoulder Pressure Levels")
                        .font(.headline)

                    HStack(spacing: 20) {
                        TriggerBarView(title: "L1 Shoulder", value: viewModel.mappedState.buttonL1 ? 1.0 : 0.0)
                        TriggerBarView(title: "L2 Trigger", value: viewModel.mappedState.triggerL2)
                        TriggerBarView(title: "R2 Trigger", value: viewModel.mappedState.triggerR2)
                        TriggerBarView(title: "R1 Shoulder", value: viewModel.mappedState.buttonR1 ? 1.0 : 0.0)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Face Buttons Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Button State Visualizer")
                        .font(.headline)

                    HStack(spacing: 12) {
                        ButtonPillView(title: "Button 1", isPressed: viewModel.mappedState.button1)
                        ButtonPillView(title: "Button 2", isPressed: viewModel.mappedState.button2)
                        ButtonPillView(title: "Button A", isPressed: viewModel.mappedState.buttonA)
                        ButtonPillView(title: "Button B", isPressed: viewModel.mappedState.buttonB)
                        ButtonPillView(title: "Takeoff / Land", isPressed: viewModel.mappedState.buttonTakeoffLand)
                        ButtonPillView(title: "Flip", isPressed: viewModel.mappedState.buttonFlip)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .bold()
                    .foregroundColor(valueColor)
            }
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct StickVisualizerCard: View {
    let title: String
    let x: Float
    let y: Float

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .background(Circle().fill(Color(NSColor.windowBackgroundColor)))

                // Crosshair
                Path { path in
                    path.move(to: CGPoint(x: 80, y: 10))
                    path.addLine(to: CGPoint(x: 80, y: 150))
                    path.move(to: CGPoint(x: 10, y: 80))
                    path.addLine(to: CGPoint(x: 150, y: 80))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                // Stick Position Circle (Centered at (80, 80) when x=0, y=0)
                let posX = 80 + CGFloat(x) * 65
                let posY = 80 - CGFloat(y) * 65

                Circle()
                    .fill(Color.accentColor)
                    .shadow(radius: 4)
                    .frame(width: 22, height: 22)
                    .position(x: posX, y: posY)
            }
            .frame(width: 160, height: 160)

            Text(String(format: "X: %+.2f | Y: %+.2f", x, y))
                .font(.callout)
                .monospacedDigit()
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TriggerBarView: View {
    let title: String
    let value: Float

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .bold()

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                        .frame(height: geo.size.height * CGFloat(value))
                }
            }
            .frame(height: 80)

            Text(String(format: "%.0f%%", value * 100))
                .font(.caption2)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ButtonPillView: View {
    let title: String
    let isPressed: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isPressed ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPressed ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
