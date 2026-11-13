import SwiftUI

public struct ScannerView: View {
    @ObservedObject var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header / Connection Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parrot Flypad Device Scanner")
                        .font(.title2)
                        .bold()
                    Text("Wirelessly scan, pair, and connect your Bluetooth LE Flypad controller.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                StatusBadgeView(state: viewModel.bleManager.connectionState)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            // Action Toolbar & Filter Toggle
            HStack(spacing: 16) {
                if viewModel.bleManager.connectionState == .scanning {
                    Button(action: { viewModel.stopScan() }) {
                        Label("Stop Scanning", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: { viewModel.startScan() }) {
                        Label("Start Scan", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if case .ready = viewModel.bleManager.connectionState {
                    Button(action: { viewModel.disconnect() }) {
                        Label("Disconnect Device", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Toggle("Show Flypad Only", isOn: $viewModel.bleManager.showOnlyFlypadDevices)
                    .toggleStyle(.switch)
                    .onChange(of: viewModel.bleManager.showOnlyFlypadDevices) { _, newValue in
                        if newValue {
                            viewModel.bleManager.startScan()
                        }
                    }
            }
            .padding(.horizontal)

            // Device List
            List {
                Section(header: Text(viewModel.bleManager.showOnlyFlypadDevices ? "Flypad Controllers Found" : "All Discovered Bluetooth Devices")) {
                    if viewModel.bleManager.discoveredDevices.isEmpty {
                        VStack(spacing: 8) {
                            Text("No \(viewModel.bleManager.showOnlyFlypadDevices ? "Flypad" : "Bluetooth") devices found nearby.")
                                .foregroundColor(.secondary)
                            Text("Click 'Start Scan' and power on your Parrot Flypad controller.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                    } else {
                        ForEach(viewModel.bleManager.discoveredDevices) { device in
                            HStack {
                                Image(systemName: device.isFlypad ? "gamecontroller.fill" : "antenna.radiowaves.left.and.right")
                                    .font(.title3)
                                    .foregroundColor(device.isFlypad ? .accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(device.name)
                                            .font(.body)
                                            .bold()
                                        if device.isFlypad {
                                            Text("FLYPAD")
                                                .font(.caption2)
                                                .bold()
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.2))
                                                .foregroundColor(.accentColor)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text("UUID: \(device.id)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(device.rssi) dBm")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)

                                let isConnectingThisDevice = (viewModel.bleManager.connectionState == .connecting(device.name) ||
                                                              viewModel.bleManager.connectionState == .discoveringServices(device.name))

                                Button(action: { viewModel.connect(device: device) }) {
                                    if isConnectingThisDevice {
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Connecting...")
                                        }
                                    } else {
                                        Text("Connect")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(isConnectingThisDevice)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding()
    }
}

struct StatusBadgeView: View {
    let state: BLEConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.callout)
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(16)
    }

    private var statusColor: Color {
        switch state {
        case .ready: return .green
        case .scanning: return .blue
        case .connecting, .discoveringServices: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    private var statusText: String {
        switch state {
        case .ready(let name, _): return "Connected (\(name))"
        case .scanning: return "Scanning..."
        case .connecting(let name): return "Connecting (\(name))..."
        case .discoveringServices: return "Discovering Services..."
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
