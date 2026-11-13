import Foundation
import Combine

@MainActor
public final class ScannerViewModel: ObservableObject {
    @Published public var bleManager: FlypadBLEManager
    private var cancellables = Set<AnyCancellable>()

    public init(bleManager: FlypadBLEManager) {
        self.bleManager = bleManager

        // Forward bleManager's objectWillChange notifications so SwiftUI updates in real time
        bleManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func startScan() {
        bleManager.startScan()
    }

    public func stopScan() {
        bleManager.stopScan()
    }

    public func connect(device: DiscoveredDevice) {
        bleManager.connect(device: device)
    }

    public func disconnect() {
        bleManager.disconnect()
    }
}
