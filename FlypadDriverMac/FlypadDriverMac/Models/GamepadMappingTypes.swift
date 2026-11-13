import Foundation

public enum FlypadButtonSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case button1 = "Button 1"
    case button2 = "Button 2"
    case buttonA = "Button A"
    case buttonB = "Button B"
    case buttonFlip = "Flip Button"
    case buttonL1 = "L1 Shoulder"
    case buttonR1 = "R1 Shoulder"
    case buttonL2 = "L2 Trigger"
    case buttonR2 = "R2 Trigger"
    case buttonL3 = "L3 (Left Stick Click)"
    case buttonR3 = "R3 (Right Stick Click)"

    public var id: String { rawValue }
}

public enum GamepadButtonTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case buttonA = "Virtual Button A"
    case buttonB = "Virtual Button B"
    case buttonX = "Virtual Button X"
    case buttonY = "Virtual Button Y"
    case buttonL1 = "Virtual Left Shoulder"
    case buttonR1 = "Virtual Right Shoulder"
    case triggerL2 = "Virtual Left Trigger"
    case triggerR2 = "Virtual Right Trigger"
    case buttonL3 = "Virtual Left Thumbstick Press"
    case buttonR3 = "Virtual Right Thumbstick Press"

    public var id: String { rawValue }
}

public enum FlypadAxisSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case roll = "Roll (Left Stick X)"
    case pitch = "Pitch (Left Stick Y)"
    case yaw = "Yaw (Right Stick X)"
    case gaz = "Gaz (Right Stick Y)"

    public var id: String { rawValue }
}

public enum GamepadAxisTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case leftStickX = "Left Stick X"
    case leftStickY = "Left Stick Y"
    case rightStickX = "Right Stick X"
    case rightStickY = "Right Stick Y"

    public var id: String { rawValue }
}
