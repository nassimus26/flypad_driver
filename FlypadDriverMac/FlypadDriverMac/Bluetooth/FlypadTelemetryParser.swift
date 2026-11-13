import Foundation

public enum FlypadTelemetryParser {

    public static func parse(_ bytes: Data) -> FlypadTelemetry {
        if bytes.isEmpty {
            return FlypadTelemetry(rawBytes: bytes)
        }

        if bytes.count >= 5 {
            return parseStandardFlypadReport(bytes)
        } else if bytes.count == 1 {
            return parseBatteryReport(bytes)
        } else {
            return FlypadTelemetry(timestamp: Date(), rawBytes: bytes)
        }
    }

    private static func parseStandardFlypadReport(_ bytes: Data) -> FlypadTelemetry {
        // Hardware packet layout from Parrot Flypad characteristic 9E35FA01:
        // bytes[0]: Header ID (0x3C)
        // bytes[1]: Button Mask 1 (0x01=Flip, 0x02=Button1, 0x04=Button2, 0x08=ButtonB, 0x10=ButtonA, 0x20=R1, 0x40=R2, 0x80=L1)
        // bytes[2]: Button Mask 2 (0x01=L2, 0x02=L3 Stick Press, 0x04=R3 Stick Press)
        // bytes[3]: Yaw (Right Stick X)
        // bytes[4]: Gaz (Right Stick Y)
        // bytes[5]: Roll (Left Stick X)
        // bytes[6]: Pitch (Left Stick Y)

        let btnMask1 = Int(bytes.count > 1 ? bytes[1] : 0)
        let btnMask2 = Int(bytes.count > 2 ? bytes[2] : 0)

        let btnFlip = (btnMask1 & 0x01) != 0
        let btn1    = (btnMask1 & 0x02) != 0
        let btn2    = (btnMask1 & 0x04) != 0
        let btnB    = (btnMask1 & 0x08) != 0
        let btnA    = (btnMask1 & 0x10) != 0
        let btnR1   = (btnMask1 & 0x20) != 0
        let btnR2   = (btnMask1 & 0x40) != 0
        let btnL1   = (btnMask1 & 0x80) != 0

        let btnL2   = (btnMask2 & 0x01) != 0
        let btnL3   = (btnMask2 & 0x02) != 0
        let btnR3   = (btnMask2 & 0x04) != 0

        // Thumbsticks (Left Stick = bytes[5] & bytes[6], Right Stick = bytes[3] & bytes[4])
        let rollRaw = bytes.count > 5 ? bytes[5] : 128
        let pitchRaw = bytes.count > 6 ? bytes[6] : 128
        let yawRaw = bytes.count > 3 ? bytes[3] : 128
        let gazRaw = bytes.count > 4 ? bytes[4] : 128

        let roll = normalizeAxis(rollRaw)
        let pitch = normalizeAxis(pitchRaw)
        let yaw = normalizeAxis(yawRaw)
        let gaz = normalizeAxis(gazRaw)

        let battery = bytes.count >= 8 ? Int(bytes[7]) : -1

        return FlypadTelemetry(
            timestamp: Date(),
            roll: roll,
            pitch: pitch,
            yaw: yaw,
            gaz: gaz,
            button1: btn1,
            button2: btn2,
            buttonA: btnA,
            buttonB: btnB,
            buttonFlip: btnFlip,
            buttonL1: btnL1,
            buttonR1: btnR1,
            buttonL2: btnL2,
            buttonR2: btnR2,
            buttonL3: btnL3,
            buttonR3: btnR3,
            batteryLevel: (0...100).contains(battery) ? battery : -1,
            rawBytes: bytes
        )
    }

    private static func parseBatteryReport(_ bytes: Data) -> FlypadTelemetry {
        let level = Int(bytes[0])
        return FlypadTelemetry(
            batteryLevel: (0...100).contains(level) ? level : -1,
            rawBytes: bytes
        )
    }

    private static func normalizeAxis(_ rawByte: UInt8) -> Float {
        // Standard Flypad BLE telemetry sends unsigned 0..255 byte centered at 128 (0x80 = 0.0)
        let centeredFloat = Float(rawByte) - 128.0
        let normalized = centeredFloat / 127.0
        return max(-1.0, min(1.0, normalized))
    }
}
