import Foundation

public struct MappedGamepadState: Sendable, Equatable {
    public var leftStickX: Float
    public var leftStickY: Float
    public var rightStickX: Float
    public var rightStickY: Float

    public var button1: Bool
    public var button2: Bool
    public var buttonA: Bool
    public var buttonB: Bool
    public var buttonFlip: Bool
    public var buttonL1: Bool
    public var buttonR1: Bool
    public var triggerL2: Float
    public var triggerR2: Float
    public var buttonL3: Bool
    public var buttonR3: Bool
    public var batteryLevel: Int

    public init(
        leftStickX: Float = 0.0,
        leftStickY: Float = 0.0,
        rightStickX: Float = 0.0,
        rightStickY: Float = 0.0,
        button1: Bool = false,
        button2: Bool = false,
        buttonA: Bool = false,
        buttonB: Bool = false,
        buttonFlip: Bool = false,
        buttonL1: Bool = false,
        buttonR1: Bool = false,
        triggerL2: Float = 0.0,
        triggerR2: Float = 0.0,
        buttonL3: Bool = false,
        buttonR3: Bool = false,
        batteryLevel: Int = -1
    ) {
        self.leftStickX = leftStickX
        self.leftStickY = leftStickY
        self.rightStickX = rightStickX
        self.rightStickY = rightStickY
        self.button1 = button1
        self.button2 = button2
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonFlip = buttonFlip
        self.buttonL1 = buttonL1
        self.buttonR1 = buttonR1
        self.triggerL2 = triggerL2
        self.triggerR2 = triggerR2
        self.buttonL3 = buttonL3
        self.buttonR3 = buttonR3
        self.batteryLevel = batteryLevel
    }
}
