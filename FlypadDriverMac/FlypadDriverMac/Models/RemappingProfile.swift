import Foundation

public struct AxisMappingConfig: Codable, Sendable, Equatable {
    public var targetAxis: GamepadAxisTarget
    public var isInverted: Bool
    public var deadzone: Float // 0.0 .. 0.5

    public init(targetAxis: GamepadAxisTarget, isInverted: Bool = false, deadzone: Float = 0.05) {
        self.targetAxis = targetAxis
        self.isInverted = isInverted
        self.deadzone = deadzone
    }
}

public struct ButtonMappingConfig: Codable, Sendable, Equatable {
    public var targetButton: GamepadButtonTarget

    public init(targetButton: GamepadButtonTarget) {
        self.targetButton = targetButton
    }
}

public struct RemappingProfile: Codable, Sendable, Equatable {
    public var profileName: String
    public var globalDeadzone: Float
    public var axisMappings: [FlypadAxisSource: AxisMappingConfig]
    public var buttonMappings: [FlypadButtonSource: ButtonMappingConfig]

    public init(
        profileName: String = "Default Profile",
        globalDeadzone: Float = 0.05,
        axisMappings: [FlypadAxisSource: AxisMappingConfig] = RemappingProfile.defaultAxisMappings(),
        buttonMappings: [FlypadButtonSource: ButtonMappingConfig] = RemappingProfile.defaultButtonMappings()
    ) {
        self.profileName = profileName
        self.globalDeadzone = globalDeadzone
        self.axisMappings = axisMappings
        self.buttonMappings = buttonMappings
    }

    public static func defaultAxisMappings() -> [FlypadAxisSource: AxisMappingConfig] {
        return [
            .roll: AxisMappingConfig(targetAxis: .leftStickX, isInverted: false, deadzone: 0.05),
            .pitch: AxisMappingConfig(targetAxis: .leftStickY, isInverted: false, deadzone: 0.05),
            .yaw: AxisMappingConfig(targetAxis: .rightStickX, isInverted: false, deadzone: 0.05),
            .gaz: AxisMappingConfig(targetAxis: .rightStickY, isInverted: false, deadzone: 0.05)
        ]
    }

    public static func defaultButtonMappings() -> [FlypadButtonSource: ButtonMappingConfig] {
        return [
            .button1: ButtonMappingConfig(targetButton: .buttonX),
            .button2: ButtonMappingConfig(targetButton: .buttonY),
            .buttonA: ButtonMappingConfig(targetButton: .buttonA),
            .buttonB: ButtonMappingConfig(targetButton: .buttonB),
            .buttonFlip: ButtonMappingConfig(targetButton: .buttonX),
            .buttonL1: ButtonMappingConfig(targetButton: .buttonL1),
            .buttonR1: ButtonMappingConfig(targetButton: .buttonR1),
            .buttonL2: ButtonMappingConfig(targetButton: .triggerL2),
            .buttonR2: ButtonMappingConfig(targetButton: .triggerR2),
            .buttonL3: ButtonMappingConfig(targetButton: .buttonL3),
            .buttonR3: ButtonMappingConfig(targetButton: .buttonR3)
        ]
    }
}
