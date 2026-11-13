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
        }
        .onChange(of: mappingViewModel.profile) { _, newProfile in
            visualizerViewModel.updateProfile(newProfile)
        }
    }
}
