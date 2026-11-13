import Foundation
import Combine

@MainActor
public final class MappingViewModel: ObservableObject {
    @Published public var profile: RemappingProfile {
        didSet {
            saveProfile()
        }
    }

    private let profileKey = "SavedFlypadRemappingProfile"

    public init() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(RemappingProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = RemappingProfile()
        }
    }

    public func updateGlobalDeadzone(_ value: Float) {
        profile.globalDeadzone = value
    }

    public func toggleAxisInversion(source: FlypadAxisSource) {
        guard var config = profile.axisMappings[source] else { return }
        config.isInverted.toggle()
        profile.axisMappings[source] = config
    }

    public func updateAxisDeadzone(source: FlypadAxisSource, deadzone: Float) {
        guard var config = profile.axisMappings[source] else { return }
        config.deadzone = deadzone
        profile.axisMappings[source] = config
    }

    public func updateButtonMapping(source: FlypadButtonSource, target: GamepadButtonTarget) {
        profile.buttonMappings[source] = ButtonMappingConfig(targetButton: target)
    }

    public func resetToDefaults() {
        profile = RemappingProfile()
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
}
