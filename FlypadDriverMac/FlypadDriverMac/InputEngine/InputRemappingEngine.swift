import Foundation

public actor InputRemappingEngine {

    public init() {}

    public func map(telemetry: FlypadTelemetry, profile: RemappingProfile) -> MappedGamepadState {
        var state = MappedGamepadState(batteryLevel: telemetry.batteryLevel)

        // Process Axes
        for (sourceAxis, config) in profile.axisMappings {
            let rawValue = getRawAxisValue(from: telemetry, source: sourceAxis)
            let processedValue = applyDeadzoneAndInversion(
                value: rawValue,
                deadzone: max(config.deadzone, profile.globalDeadzone),
                isInverted: config.isInverted
            )

            switch config.targetAxis {
            case .leftStickX:
                state.leftStickX = processedValue
            case .leftStickY:
                state.leftStickY = processedValue
            case .rightStickX:
                state.rightStickX = processedValue
            case .rightStickY:
                state.rightStickY = processedValue
            }
        }

        // Process Buttons
        state.button1 = telemetry.button1
        state.button2 = telemetry.button2
        state.buttonA = telemetry.buttonA
        state.buttonB = telemetry.buttonB
        state.buttonTakeoffLand = telemetry.buttonTakeoffLand
        state.buttonFlip = telemetry.buttonFlip
        state.buttonL1 = telemetry.buttonL1
        state.buttonR1 = telemetry.buttonR1
        state.triggerL2 = telemetry.buttonL2 ? 1.0 : 0.0
        state.triggerR2 = telemetry.buttonR2 ? 1.0 : 0.0

        return state
    }

    private func getRawAxisValue(from telemetry: FlypadTelemetry, source: FlypadAxisSource) -> Float {
        switch source {
        case .roll: return telemetry.roll
        case .pitch: return telemetry.pitch
        case .yaw: return telemetry.yaw
        case .gaz: return telemetry.gaz
        }
    }

    private func getRawButtonValue(from telemetry: FlypadTelemetry, source: FlypadButtonSource) -> Bool {
        switch source {
        case .button1: return telemetry.button1
        case .button2: return telemetry.button2
        case .buttonA: return telemetry.buttonA
        case .buttonB: return telemetry.buttonB
        case .buttonTakeoffLand: return telemetry.buttonTakeoffLand
        case .buttonFlip: return telemetry.buttonFlip
        case .buttonL1: return telemetry.buttonL1
        case .buttonR1: return telemetry.buttonR1
        case .buttonL2: return telemetry.buttonL2
        case .buttonR2: return telemetry.buttonR2
        }
    }

    private func applyDeadzoneAndInversion(value: Float, deadzone: Float, isInverted: Bool) -> Float {
        let signedVal = isInverted ? -value : value
        let mag = abs(signedVal)
        if mag < deadzone { return 0.0 }

        let rescaled = (mag - deadzone) / (1.0 - deadzone)
        let result = (signedVal >= 0 ? 1.0 : -1.0) * rescaled
        return max(-1.0, min(1.0, result))
    }
}
