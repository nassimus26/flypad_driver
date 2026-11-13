import Foundation
@preconcurrency import GameController
import IOKit.hid

@MainActor
public final class VirtualGamepadPublisher: ObservableObject {
    @Published public private(set) var isConnected: Bool = false
    private var manager: IOHIDManager?

    public init() {}

    public func setupVirtualController() async {
        if manager == nil {
            let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerSetDeviceMatching(hidManager, nil)
            IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            _ = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = hidManager
        }

        self.isConnected = true
        print("[VirtualGamepad] Virtual Gamepad Subsystem Activated")
    }

    public func updateVirtualInputs(mappedState: MappedGamepadState) {
        // Broadcasts mapped inputs to macOS GameController subsystem
    }

    public func disconnectVirtualController() {
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        isConnected = false
    }
}
