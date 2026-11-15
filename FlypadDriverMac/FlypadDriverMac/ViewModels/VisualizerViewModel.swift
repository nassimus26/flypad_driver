import CoreGraphics
import Foundation
import Combine

@MainActor
public final class VisualizerViewModel: ObservableObject {
    @Published public private(set) var connectionState: BLEConnectionState = .disconnected
    @Published public private(set) var rawTelemetry = FlypadTelemetry()
    @Published public private(set) var mappedState = MappedGamepadState()
    @Published public private(set) var packetsPerSecond: Int = 0
    @Published public private(set) var virtualControllerConnected: Bool = false

    private let bleManager: FlypadBLEManager
    private let virtualPublisher: VirtualGamepadPublisher
    public var virtualControllerStatus: String { virtualPublisher.statusMessage }
    public var dsuRunning: Bool { virtualPublisher.dsuRunning }
    public var dsuClientCount: Int { virtualPublisher.dsuClientCount }
    @Published public private(set) var keyboardEmulationAllowed: Bool = CGPreflightPostEventAccess()
    public func requestKeyboardEmulationAccess() { virtualPublisher.requestKeyboardPostAccess() }
    private let remappingEngine = InputRemappingEngine()
    @Published public var profile: RemappingProfile = RemappingProfile()

    private var cancellables = Set<AnyCancellable>()

    public init(bleManager: FlypadBLEManager, virtualPublisher: VirtualGamepadPublisher) {
        self.bleManager = bleManager
        self.virtualPublisher = virtualPublisher

        setupSubscriptions()
    }

    public func setupVirtualController() async {
        await virtualPublisher.setupVirtualController()
    }

    public func toggleInvertLeftY() {
        if var config = profile.axisMappings[.pitch] {
            config.isInverted.toggle()
            profile.axisMappings[.pitch] = config
            updateProfile(profile)
        }
    }

    public func toggleInvertRightY() {
        if var config = profile.axisMappings[.gaz] {
            config.isInverted.toggle()
            profile.axisMappings[.gaz] = config
            updateProfile(profile)
        }
    }

    private func setupSubscriptions() {
        // Forward bleManager and virtualPublisher objectWillChange notifications on main thread
        bleManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        virtualPublisher.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        bleManager.$connectionState
            .receive(on: RunLoop.main)
            .assign(to: &$connectionState)

        bleManager.$latestTelemetry
            .receive(on: RunLoop.main)
            .sink { [weak self] telemetry in
                guard let self = self else { return }
                self.rawTelemetry = telemetry
                Task {
                    let mapped = await self.remappingEngine.map(telemetry: telemetry, profile: self.profile)
                    await MainActor.run {
                        self.mappedState = mapped
                        self.virtualPublisher.updateVirtualInputs(mappedState: mapped)
                    }
                }
            }
            .store(in: &cancellables)

        // Re-check Accessibility every 2 s so the banner disappears as soon as it is granted.
        Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .map { _ in CGPreflightPostEventAccess() }
            .removeDuplicates()
            .assign(to: &$keyboardEmulationAllowed)

        bleManager.$packetsPerSecond
            .receive(on: RunLoop.main)
            .assign(to: &$packetsPerSecond)

        virtualPublisher.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                self?.virtualControllerConnected = isConnected
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func updateProfile(_ newProfile: RemappingProfile) {
        self.profile = newProfile
    }
}
