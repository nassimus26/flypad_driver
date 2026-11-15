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
    @Published public private(set) var dsuRunning: Bool = false
    @Published public private(set) var dsuClientCount: Int = 0

    /// Direct-to-emulator UDP output (no driver needed).
    public let dsuServer = DSUServer()
    /// RetroArch Network RetroPad output (UDP 127.0.0.1:55400).
    public let retroPadSender = RetroPadSender()

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

    public init() {
        dsuServer.onClientCountChanged = { [weak self] count in
            Task { @MainActor in self?.dsuClientCount = count }
        }
        dsuRunning = dsuServer.start()
    }

    /// Keyboard emulation (CGEvent.post) needs Accessibility permission, not Input Monitoring.
    public var hasKeyboardPostAccess: Bool { CGPreflightPostEventAccess() }

    public func requestKeyboardPostAccess() {
        _ = CGRequestPostEventAccess()
    }

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
            self.statusMessage = "Active (Virtual System Gamepad)"
            print("[VirtualGamepad] Successfully created and scheduled IOHIDUserDevice Virtual Gamepad to macOS HID system!")
        } else {
            self.isConnected = false
            self.statusMessage = "Virtual HID gamepad unavailable: macOS requires the restricted 'com.apple.developer.hid.virtual.device' entitlement (Apple-approved provisioning profile). Keyboard emulation is used instead."
            print("[VirtualGamepad ERROR] IOHIDUserDeviceCreate returned nil. This is caused by the missing com.apple.developer.hid.virtual.device entitlement, not Input Monitoring.")
        }
    }

    public func updateVirtualInputs(mappedState: MappedGamepadState) {
        // 0. Direct-to-emulator output via DSU / Cemuhook UDP protocol
        dsuServer.update(mappedState)
        retroPadSender.update(mappedState)

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

// MARK: - DSU (Cemuhook) UDP server
//
// Sends the Flypad state straight to emulators over UDP. No virtual HID driver
// or entitlement is needed. Supported by Dolphin, Cemu, Ryujinx, Citra/Lime3DS, etc.
// In the emulator, add a DSU client pointing to 127.0.0.1 : 26760.

public final class DSUServer: @unchecked Sendable {
    public static let defaultPort: UInt16 = 26760

    private let queue = DispatchQueue(label: "flypad.dsu.server")
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let serverID: UInt32 = UInt32.random(in: 1...UInt32.max)
    private var packetCounter: UInt32 = 0
    private var lastState = MappedGamepadState()
    private let mac: [UInt8] = [0x00, 0x46, 0x4C, 0x59, 0x50, 0x01] // fake MAC "FLYP"
    /// Clients subscribed to pad data, with the time of their last request.
    private var clients: [Data: (addr: sockaddr_in, lastSeen: Date)] = [:]

    public var onClientCountChanged: (@Sendable (Int) -> Void)?
    public private(set) var isRunning = false

    public init() {}

    @discardableResult
    public func start(port: UInt16 = DSUServer.defaultPort) -> Bool {
        queue.sync {
            guard socketFD < 0 else { return true }
            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard fd >= 0 else { return false }
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = port.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bound = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bound == 0 else {
                print("[DSU ERROR] bind to 127.0.0.1:\(port) failed (errno \(errno))")
                close(fd)
                return false
            }
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
            socketFD = fd

            let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            src.setEventHandler { [weak self] in self?.readPending() }
            src.resume()
            readSource = src
            isRunning = true
            print("[DSU] Server listening on 127.0.0.1:\(port)")
            return true
        }
    }

    public func stop() {
        queue.sync {
            readSource?.cancel()
            readSource = nil
            if socketFD >= 0 { close(socketFD) }
            socketFD = -1
            clients.removeAll()
            isRunning = false
        }
        onClientCountChanged?(0)
    }

    public func update(_ state: MappedGamepadState) {
        queue.async { [weak self] in
            guard let self else { return }
            self.lastState = state
            self.broadcastPadData()
        }
    }

    // MARK: Receiving

    private func readPending() {
        var buf = [UInt8](repeating: 0, count: 1024)
        while true {
            var from = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFD, &buf, buf.count, 0, $0, &len)
                }
            }
            if n <= 0 { break }
            handle(Array(buf[0..<n]), from: from)
        }
    }

    private func handle(_ p: [UInt8], from: sockaddr_in) {
        guard p.count >= 20, p[0] == 0x44, p[1] == 0x53, p[2] == 0x55, p[3] == 0x43 else { return } // "DSUC"
        let type = readU32(p, 16)
        switch type {
        case 0x100000: // protocol version
            var payload = u32(0x100000)
            payload += [0xE9, 0x03] // 1001
            send(payload, to: from)
        case 0x100001: // controller info
            guard p.count >= 24 else { return }
            let count = Int(readU32(p, 20))
            for i in 0..<min(count, 4) where p.count > 24 + i {
                let slot = p[24 + i]
                var payload = u32(0x100001)
                payload += sharedHeader(slot: slot)
                payload.append(0)
                send(payload, to: from)
            }
        case 0x100002: // pad data subscription
            let key = addrKey(from)
            let isNew = clients[key] == nil
            clients[key] = (from, Date())
            if isNew { notifyCount() }
            sendPadData(to: from)
        default:
            break
        }
    }

    // MARK: Sending

    private func broadcastPadData() {
        let now = Date()
        let before = clients.count
        clients = clients.filter { now.timeIntervalSince($0.value.lastSeen) < 5 }
        if clients.count != before { notifyCount() }
        for c in clients.values { sendPadData(to: c.addr) }
    }

    private func sendPadData(to addr: sockaddr_in) {
        let s = lastState
        packetCounter &+= 1

        func axis(_ v: Float) -> UInt8 { UInt8(clamping: Int((max(-1, min(1, v)) * 127.0).rounded()) + 128) }
        func an(_ b: Bool) -> UInt8 { b ? 255 : 0 }
        func trig(_ v: Float) -> UInt8 { UInt8(clamping: Int(max(0, min(1, v)) * 255)) }

        // DualShock bit order (as DS4Windows sends it).
        // buttons1: Share 0x01, L3 0x02, R3 0x04, Options 0x08, Up 0x10, Right 0x20, Down 0x40, Left 0x80
        var b1: UInt8 = 0
        if s.buttonL3 { b1 |= 0x02 }
        if s.buttonR3 { b1 |= 0x04 }
        if s.buttonFlip { b1 |= 0x08 } // Options (needed by PS games to pause / start)
        // buttons2: L2 0x01, R2 0x02, L1 0x04, R1 0x08, Triangle 0x10, Circle 0x20, Cross 0x40, Square 0x80
        // Positional layout: A = bottom = Cross, B = right = Circle, X (button1) = left = Square, Y (button2) = top = Triangle.
        var b2: UInt8 = 0
        if s.triggerL2 > 0.5 { b2 |= 0x01 }
        if s.triggerR2 > 0.5 { b2 |= 0x02 }
        if s.buttonL1 { b2 |= 0x04 }
        if s.buttonR1 { b2 |= 0x08 }
        if s.button2 { b2 |= 0x10 }  // Triangle
        if s.buttonB { b2 |= 0x20 }  // Circle
        if s.buttonA { b2 |= 0x40 }  // Cross
        if s.button1 { b2 |= 0x80 }  // Square

        var p = u32(0x100002)
        p += sharedHeader(slot: 0)
        p.append(1)                    // connected
        p += u32(packetCounter)
        p += [b1, b2, 0, 0]            // buttons1, buttons2, PS/home, touch button
        p += [axis(s.leftStickX), axis(s.leftStickY), axis(s.rightStickX), axis(s.rightStickY)] // Y: up = 255
        p += [0, 0, 0, 0]              // analog D-pad L, D, R, U
        p += [an(s.button1), an(s.buttonA), an(s.buttonB), an(s.button2)] // Square, Cross, Circle, Triangle
        p += [an(s.buttonR1), an(s.buttonL1), trig(s.triggerR2), trig(s.triggerL2)]
        p += [UInt8](repeating: 0, count: 12) // two touch points
        let us = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        p += withUnsafeBytes(of: us.littleEndian) { Array($0) }
        p += [UInt8](repeating: 0, count: 24)  // accel + gyro
        send(p, to: addr)
    }

    private func sharedHeader(slot: UInt8) -> [UInt8] {
        let connected = slot == 0
        let battery: UInt8 = {
            let lvl = lastState.batteryLevel
            if lvl < 0 { return 0x00 }
            switch lvl { case ..<10: return 0x01; case ..<25: return 0x02; case ..<75: return 0x03; case ..<95: return 0x04; default: return 0x05 }
        }()
        return [slot, connected ? 2 : 0, connected ? 2 : 0, connected ? 2 : 0] + (connected ? mac : [0, 0, 0, 0, 0, 0]) + [connected ? battery : 0]
    }

    private func send(_ payload: [UInt8], to addr: sockaddr_in) {
        var packet: [UInt8] = [0x44, 0x53, 0x55, 0x53, 0xE9, 0x03] // "DSUS", version 1001
        packet += withUnsafeBytes(of: UInt16(payload.count).littleEndian) { Array($0) } // length after the 16-byte header
        packet += [0, 0, 0, 0]                                   // CRC placeholder
        packet += u32(serverID)
        packet += payload
        let crc = DSUServer.crc32(packet)
        packet.replaceSubrange(8..<12, with: u32(crc))
        var a = addr
        _ = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &a) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socketFD, raw.baseAddress, raw.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    // MARK: Helpers

    private func notifyCount() { onClientCountChanged?(clients.count) }

    private func addrKey(_ a: sockaddr_in) -> Data {
        var k = a
        return Data(bytes: &k, count: MemoryLayout<sockaddr_in>.size)
    }

    private func u32(_ v: UInt32) -> [UInt8] { withUnsafeBytes(of: v.littleEndian) { Array($0) } }
    private func readU32(_ p: [UInt8], _ o: Int) -> UInt32 {
        UInt32(p[o]) | UInt32(p[o + 1]) << 8 | UInt32(p[o + 2]) << 16 | UInt32(p[o + 3]) << 24
    }

    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32(_ data: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in data { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
}

// MARK: - RetroArch "Network RetroPad" sender
//
// RetroArch (Settings > Network > Network RetroPad, and enable it for User 1) listens on
// UDP 55400 + user index. Each packet is RetroArch's `struct remote_message`:
// { int32 port; int32 device; int32 index; int32 id; uint16 state; } = 20 bytes with padding,
// in host (little-endian) byte order. RetroArch has no reply, so this is fire-and-forget.

public final class RetroPadSender: @unchecked Sendable {
    public static let defaultPort: UInt16 = 55400

    private enum Device: Int32 { case joypad = 1, analog = 5 }
    // libretro RETRO_DEVICE_ID_JOYPAD_*
    private enum Pad: Int32 { case b = 0, y, select, start, up, down, left, right, a, x, l, r, l2, r2, l3, r3 }

    private let queue = DispatchQueue(label: "flypad.retropad.sender")
    private var fd: Int32 = -1
    private var dest = sockaddr_in()

    public init(port: UInt16 = RetroPadSender.defaultPort) {
        fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = port.bigEndian
        dest.sin_addr.s_addr = inet_addr("127.0.0.1")
    }

    deinit { if fd >= 0 { close(fd) } }

    /// Sends the full pad state every update, so RetroArch picks it up even if started later.
    public func update(_ s: MappedGamepadState) {
        queue.async { [weak self] in
            guard let self, self.fd >= 0 else { return }
            // Positional (Xbox-style) layout: Flypad A = bottom face button = RetroPad B.
            let buttons: [(Pad, Bool)] = [
                (.b, s.buttonA), (.a, s.buttonB), (.y, s.button1), (.x, s.button2),
                (.l, s.buttonL1), (.r, s.buttonR1),
                (.l2, s.triggerL2 > 0.5), (.r2, s.triggerR2 > 0.5),
                (.l3, s.buttonL3), (.r3, s.buttonR3),
                (.start, s.buttonFlip)
            ]
            for (id, pressed) in buttons {
                self.send(device: .joypad, index: 0, id: id.rawValue, state: pressed ? 1 : 0)
            }
            // Analog: index 0 = left, 1 = right; id 0 = X, 1 = Y. libretro Y is positive DOWN.
            func axis(_ v: Float) -> UInt16 {
                UInt16(bitPattern: Int16(clamping: Int((max(-1, min(1, v)) * 32767).rounded())))
            }
            self.send(device: .analog, index: 0, id: 0, state: axis(s.leftStickX))
            self.send(device: .analog, index: 0, id: 1, state: axis(-s.leftStickY))
            self.send(device: .analog, index: 1, id: 0, state: axis(s.rightStickX))
            self.send(device: .analog, index: 1, id: 1, state: axis(-s.rightStickY))
        }
    }

    private func send(device: Device, index: Int32, id: Int32, state: UInt16) {
        var msg = [UInt8](repeating: 0, count: 20)
        func put32(_ v: Int32, _ o: Int) { withUnsafeBytes(of: v.littleEndian) { msg.replaceSubrange(o..<o + 4, with: $0) } }
        put32(0, 0)                 // port (user 0)
        put32(device.rawValue, 4)
        put32(index, 8)
        put32(id, 12)
        withUnsafeBytes(of: state.littleEndian) { msg.replaceSubrange(16..<18, with: $0) }
        var d = dest
        _ = msg.withUnsafeBytes { raw in
            withUnsafePointer(to: &d) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, raw.baseAddress, raw.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
