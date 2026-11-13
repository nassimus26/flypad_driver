import Foundation

public struct FlypadTelemetry: Sendable, Equatable {
    public var timestamp: Date
    public var roll: Float // [-1.0, 1.0]
    public var pitch: Float // [-1.0, 1.0]
    public var yaw: Float // [-1.0, 1.0]
    public var gaz: Float // [-1.0, 1.0]

    public var button1: Bool
    public var button2: Bool
    public var buttonA: Bool
    public var buttonB: Bool
    public var buttonFlip: Bool
    public var buttonL1: Bool
    public var buttonR1: Bool
    public var buttonL2: Bool
    public var buttonR2: Bool
    public var buttonL3: Bool
    public var buttonR3: Bool

    public var batteryLevel: Int // 0..100, or -1 if unknown
    public var rawBytes: Data

    public init(
        timestamp: Date = Date(),
        roll: Float = 0.0,
        pitch: Float = 0.0,
        yaw: Float = 0.0,
        gaz: Float = 0.0,
        button1: Bool = false,
        button2: Bool = false,
        buttonA: Bool = false,
        buttonB: Bool = false,
        buttonFlip: Bool = false,
        buttonL1: Bool = false,
        buttonR1: Bool = false,
        buttonL2: Bool = false,
        buttonR2: Bool = false,
        buttonL3: Bool = false,
        buttonR3: Bool = false,
        batteryLevel: Int = -1,
        rawBytes: Data = Data()
    ) {
        self.timestamp = timestamp
        self.roll = roll
        self.pitch = pitch
        self.yaw = yaw
        self.gaz = gaz
        self.button1 = button1
        self.button2 = button2
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonFlip = buttonFlip
        self.buttonL1 = buttonL1
        self.buttonR1 = buttonR1
        self.buttonL2 = buttonL2
        self.buttonR2 = buttonR2
        self.buttonL3 = buttonL3
        self.buttonR3 = buttonR3
        self.batteryLevel = batteryLevel
        self.rawBytes = rawBytes
    }
}
