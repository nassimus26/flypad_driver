import Foundation
import CoreGraphics
import IOKit

private typealias IOHIDUserDeviceCreateFunc = @convention(c) (
    CFAllocator?,
    CFDictionary
) -> Unmanaged<AnyObject>?

private typealias IOHIDUserDeviceScheduleWithRunLoopFunc = @convention(c) (
    Unmanaged<AnyObject>,
    CFRunLoop,
    CFString
) -> Void

private typealias IOHIDUserDeviceHandleReportFunc = @convention(c) (
    Unmanaged<AnyObject>,
    UnsafePointer<UInt8>,
    CFIndex
) -> Int32

@MainActor
public final class VirtualGamepadPublisher: ObservableObject {
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var statusMessage: String = "Disconnected"
    @Published public var keyboardEmulationEnabled: Bool = true

    private var rawUserDevice: Unmanaged<AnyObject>?

    private lazy var ioHIDUserDeviceCreatePtr: IOHIDUserDeviceCreateFunc? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let sym = dlsym(handle, "IOHIDUserDeviceCreate") else {
            print("[VirtualGamepad ERROR] Could not locate IOHIDUserDeviceCreate symbol")
            return nil
        }
        return unsafeBitCast(sym, to: IOHIDUserDeviceCreateFunc.self)
    }()

    private lazy var ioHIDUserDeviceScheduleWithRunLoopPtr: IOHIDUserDeviceScheduleWithRunLoopFunc? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let sym = dlsym(handle, "IOHIDUserDeviceScheduleWithRunLoop") else {
            print("[VirtualGamepad ERROR] Could not locate IOHIDUserDeviceScheduleWithRunLoop symbol")
            return nil
        }
        return unsafeBitCast(sym, to: IOHIDUserDeviceScheduleWithRunLoopFunc.self)
    }()

    private lazy var ioHIDUserDeviceHandleReportPtr: IOHIDUserDeviceHandleReportFunc? = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let sym = dlsym(handle, "IOHIDUserDeviceHandleReport") else {
            print("[VirtualGamepad ERROR] Could not locate IOHIDUserDeviceHandleReport symbol")
            return nil
        }
        return unsafeBitCast(sym, to: IOHIDUserDeviceHandleReportFunc.self)
    }()

    // Standard HID Gamepad Report Descriptor (4 Axes: X, Y, Z, Rz | 12 Digital Buttons)
    private static let hidReportDescriptor: [UInt8] = [
        0x05, 0x01,        // USAGE_PAGE (Generic Desktop)
        0x09, 0x05,        // USAGE (Game Pad)
        0xa1, 0x01,        // COLLECTION (Application)
        0x85, 0x01,        //   REPORT_ID (1)

        // 4 Analog Axes (X, Y, Z, Rz)
        0x05, 0x01,        //   USAGE_PAGE (Generic Desktop)
        0x09, 0x30,        //   USAGE (X - Left Stick X)
        0x09, 0x31,        //   USAGE (Y - Left Stick Y)
        0x09, 0x32,        //   USAGE (Z - Right Stick X)
        0x09, 0x35,        //   USAGE (Rz - Right Stick Y)
        0x15, 0x81,        //   LOGICAL_MINIMUM (-127)
        0x25, 0x7f,        //   LOGICAL_MAXIMUM (127)
        0x75, 0x08,        //   REPORT_SIZE (8 bits)
        0x95, 0x04,        //   REPORT_COUNT (4)
        0x81, 0x02,        //   INPUT (Data,Var,Abs)

        // 12 Digital Buttons (Button 1 .. 12)
        0x05, 0x09,        //   USAGE_PAGE (Button)
        0x19, 0x01,        //   USAGE_MINIMUM (Button 1)
        0x29, 0x0c,        //   USAGE_MAXIMUM (Button 12)
        0x15, 0x00,        //   LOGICAL_MINIMUM (0)
        0x25, 0x01,        //   LOGICAL_MAXIMUM (1)
        0x75, 0x01,        //   REPORT_SIZE (1 bit)
        0x95, 0x0c,        //   REPORT_COUNT (12)
        0x81, 0x02,        //   INPUT (Data,Var,Abs)

        // 4-bit Padding to align report size
        0x75, 0x04,        //   REPORT_SIZE (4 bits)
        0x95, 0x01,        //   REPORT_COUNT (1)
        0x81, 0x03,        //   INPUT (Cnst,Var,Abs)

        0xc0               // END_COLLECTION
    ]

    public init() {}

    public func setupVirtualController() async {
        if rawUserDevice != nil {
            self.isConnected = true
            return
        }

        guard let createFunc = ioHIDUserDeviceCreatePtr else {
            self.isConnected = false
            self.statusMessage = "IOHIDUserDevice API Unavailable"
            return
        }

        let descriptorData = Data(Self.hidReportDescriptor) as CFData

        let properties: [String: Any] = [
            "PrimaryUsagePage": 0x01, // Generic Desktop
            "PrimaryUsage": 0x05,     // Game Pad
            "ReportDescriptor": descriptorData,
            "VendorID": 0x054C,      // Standard Vendor
            "ProductID": 0x0CE6,     // DualSense / Gamepad Product ID
            "Product": "Parrot Flypad Virtual Gamepad"
        ]

        if let dev = createFunc(kCFAllocatorDefault, properties as CFDictionary) {
            self.rawUserDevice = dev
            if let scheduleFunc = ioHIDUserDeviceScheduleWithRunLoopPtr {
                scheduleFunc(dev, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            }
            self.isConnected = true
            self.statusMessage = "Active (System-wide Virtual HID Gamepad)"
            print("[VirtualGamepad] Successfully created and scheduled IOHIDUserDevice Virtual Gamepad to macOS HID system!")
        } else {
            self.isConnected = false
            self.statusMessage = "Failed to create HID Gamepad"
            print("[VirtualGamepad ERROR] Failed to create IOHIDUserDevice instance.")
        }
    }

    public func updateVirtualInputs(mappedState: MappedGamepadState) {
        // 1. Publish to Virtual HID Gamepad (Recognized by OpenEmu, Dolphin, PCSX2, RetroArch, Steam, etc.)
        if let dev = rawUserDevice, let sendReportFunc = ioHIDUserDeviceHandleReportPtr {
            var report = [UInt8](repeating: 0, count: 7)
            report[0] = 0x01 // Report ID

            // Analog Sticks (-1.0 to 1.0 mapped to Int8 -127 to +127)
            let lx = Int8(clamping: Int(mappedState.leftStickX * 127.0))
            let ly = Int8(clamping: Int(-mappedState.leftStickY * 127.0))
            let rx = Int8(clamping: Int(mappedState.rightStickX * 127.0))
            let ry = Int8(clamping: Int(-mappedState.rightStickY * 127.0))

            report[1] = UInt8(bitPattern: lx)
            report[2] = UInt8(bitPattern: ly)
            report[3] = UInt8(bitPattern: rx)
            report[4] = UInt8(bitPattern: ry)

            // 12 Buttons Mask
            var btnMask: UInt16 = 0
            if mappedState.buttonA { btnMask |= (1 << 0) }         // Button 1 (A)
            if mappedState.buttonB { btnMask |= (1 << 1) }         // Button 2 (B)
            if mappedState.button1 { btnMask |= (1 << 2) }         // Button 3 (X)
            if mappedState.button2 { btnMask |= (1 << 3) }         // Button 4 (Y)
            if mappedState.buttonL1 { btnMask |= (1 << 4) }        // Button 5 (L1)
            if mappedState.buttonR1 { btnMask |= (1 << 5) }        // Button 6 (R1)
            if mappedState.triggerL2 > 0.5 { btnMask |= (1 << 6) } // Button 7 (L2)
            if mappedState.triggerR2 > 0.5 { btnMask |= (1 << 7) } // Button 8 (R2)
            if mappedState.buttonL3 { btnMask |= (1 << 8) }        // Button 9 (L3)
            if mappedState.buttonR3 { btnMask |= (1 << 9) }        // Button 10 (R3)
            if mappedState.buttonFlip { btnMask |= (1 << 10) }     // Button 11 (Select/Flip)

            report[5] = UInt8(btnMask & 0xFF)
            report[6] = UInt8((btnMask >> 8) & 0xFF)

            _ = sendReportFunc(dev, report, report.count)
        }

        // 2. Keyboard Emulation Mode (Fallback for games/emulators reading keyboard)
        if keyboardEmulationEnabled {
            postKeyboardEvents(for: mappedState)
        }
    }

    private var previousKeyState: [CGKeyCode: Bool] = [:]

    private func postKeyboardEvents(for state: MappedGamepadState) {
        // Keyboard fallback mapping:
        // Left Stick -> Arrow Keys
        // Right Stick -> WASD Keys
        // Buttons -> Space, Return, Z, X, C, V, Q, E
        let keyMap: [(Bool, CGKeyCode)] = [
            (state.leftStickY > 0.4, 126),  // Up Arrow (126)
            (state.leftStickY < -0.4, 125), // Down Arrow (125)
            (state.leftStickX < -0.4, 123), // Left Arrow (123)
            (state.leftStickX > 0.4, 124),  // Right Arrow (124)

            (state.rightStickY > 0.4, 13),  // W key (13)
            (state.rightStickY < -0.4, 1),  // S key (1)
            (state.rightStickX < -0.4, 0),  // A key (0)
            (state.rightStickX > 0.4, 2),   // D key (2)

            (state.buttonA, 49),             // Spacebar (49)
            (state.buttonB, 36),             // Return / Enter (36)
            (state.button1, 6),              // Z key (6)
            (state.button2, 7),              // X key (7)
            (state.buttonL1, 12),            // Q key (12)
            (state.buttonR1, 14),            // E key (14)
            (state.triggerL2 > 0.5, 8),      // C key (8)
            (state.triggerR2 > 0.5, 9)       // V key (9)
        ]

        for (isPressed, keyCode) in keyMap {
            let wasPressed = previousKeyState[keyCode] ?? false
            if isPressed != wasPressed {
                previousKeyState[keyCode] = isPressed
                let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isPressed)
                event?.post(tap: .cghidEventTap)
            }
        }
    }

    public func disconnectVirtualController() {
        rawUserDevice = nil
        isConnected = false
        statusMessage = "Disconnected"
    }
}
