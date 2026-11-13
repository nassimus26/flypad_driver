import SwiftUI

public struct MainView: View {
    @StateObject private var scannerViewModel: ScannerViewModel
    @StateObject private var visualizerViewModel: VisualizerViewModel
    @StateObject private var mappingViewModel: MappingViewModel

    @State private var selectedTab: Tab = .scanner

    enum Tab: Hashable {
        case scanner
        case visualizer
        case mapping
    }

    public init() {
        let ble = FlypadBLEManager()
        let publisher = VirtualGamepadPublisher()

        let scannerVM = ScannerViewModel(bleManager: ble)
        let visualizerVM = VisualizerViewModel(bleManager: ble, virtualPublisher: publisher)
        let mappingVM = MappingViewModel()

        _scannerViewModel = StateObject(wrappedValue: scannerVM)
        _visualizerViewModel = StateObject(wrappedValue: visualizerVM)
        _mappingViewModel = StateObject(wrappedValue: mappingVM)
    }

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedTab) {
                    NavigationLink(value: Tab.scanner) {
                        Label("Status / Scan", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    NavigationLink(value: Tab.visualizer) {
                        Label("Input Visualizer", systemImage: "gamecontroller.fill")
                    }
                    NavigationLink(value: Tab.mapping) {
                        Label("Mapping Config", systemImage: "slider.horizontal.3")
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Footer Website Links
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://pairhint.com")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("https://pairhint.com")
                                .font(.caption)
                                .bold()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)

                    Link(destination: URL(string: "https://castmypitch.com")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("https://castmypitch.com")
                                .font(.caption)
                                .bold()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 176, ideal: 194, max: 246)
            .navigationTitle("Flypad Driver")
        } detail: {
            switch selectedTab {
            case .scanner:
                ScannerView(viewModel: scannerViewModel)
            case .visualizer:
                VisualizerView(viewModel: visualizerViewModel)
            case .mapping:
                MappingView(viewModel: mappingViewModel)
            }
        }
        .task {
            await visualizerViewModel.setupVirtualController()
            // Sync initial loaded profile from mappingViewModel to visualizerViewModel
            visualizerViewModel.updateProfile(mappingViewModel.profile)
        }
        .onChange(of: mappingViewModel.profile) { _, newProfile in
            if visualizerViewModel.profile != newProfile {
                visualizerViewModel.updateProfile(newProfile)
            }
        }
        .onChange(of: visualizerViewModel.profile) { _, newProfile in
            if mappingViewModel.profile != newProfile {
                mappingViewModel.profile = newProfile
            }
        }
    }
}
