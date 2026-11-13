import SwiftUI

public struct MappingView: View {
    @ObservedObject var viewModel: MappingViewModel

    public init(viewModel: MappingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header & Presets
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Button & Axis Remapping")
                            .font(.title2)
                            .bold()
                        Text("Customize stick deadzones, axis inversions, and controller button bindings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button("Reset Defaults") {
                        viewModel.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Invert Y-Axis (Top & Bottom Direction) Checkboxes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Invert Y-Axis (Top & Bottom Motion)")
                        .font(.headline)
                    Text("Toggle these checkboxes to invert top and bottom pitch/gaz stick directions per your preference.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 32) {
                        Toggle("Invert Left Stick Y (Top / Bottom)", isOn: Binding(
                            get: { viewModel.profile.axisMappings[.pitch]?.isInverted ?? false },
                            set: { _ in viewModel.toggleAxisInversion(source: .pitch) }
                        ))
                        .toggleStyle(.checkbox)

                        Toggle("Invert Right Stick Y (Top / Bottom)", isOn: Binding(
                            get: { viewModel.profile.axisMappings[.gaz]?.isInverted ?? false },
                            set: { _ in viewModel.toggleAxisInversion(source: .gaz) }
                        ))
                        .toggleStyle(.checkbox)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Global Deadzone Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Deadzone Threshold")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.0f%%", viewModel.profile.globalDeadzone * 100))
                            .font(.subheadline)
                            .monospacedDigit()
                            .bold()
                    }

                    Slider(
                        value: Binding(
                            get: { Float(viewModel.profile.globalDeadzone) },
                            set: { viewModel.updateGlobalDeadzone($0) }
                        ),
                        in: 0.0...0.4,
                        step: 0.01
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Axis Mapping Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analog Stick Axis Configuration")
                        .font(.headline)

                    ForEach(FlypadAxisSource.allCases) { axisSource in
                        if let config = viewModel.profile.axisMappings[axisSource] {
                            HStack {
                                Text(axisSource.rawValue)
                                    .bold()
                                    .frame(width: 180, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)

                                Text(config.targetAxis.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)

                                Spacer()

                                Toggle("Invert Axis", isOn: Binding(
                                    get: { config.isInverted },
                                    set: { _ in viewModel.toggleAxisInversion(source: axisSource) }
                                ))
                                .toggleStyle(.checkbox)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Button Remapping Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Physical Button Remapping")
                        .font(.headline)

                    ForEach(FlypadButtonSource.allCases) { btnSource in
                        if let config = viewModel.profile.buttonMappings[btnSource] {
                            HStack {
                                Text("Flypad \(btnSource.rawValue)")
                                    .bold()
                                    .frame(width: 180, alignment: .leading)

                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)

                                Picker("", selection: Binding(
                                    get: { config.targetButton },
                                    set: { newTarget in viewModel.updateButtonMapping(source: btnSource, target: newTarget) }
                                )) {
                                    ForEach(GamepadButtonTarget.allCases) { target in
                                        Text(target.rawValue).tag(target)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 220)

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
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
