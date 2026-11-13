import Foundation
import CoreBluetooth
import Combine
import os

public struct DiscoveredDevice: Identifiable, Equatable, @unchecked Sendable {
    public var id: String
    public var name: String
    public var rssi: Int
    public var isFlypad: Bool
    public var peripheral: CBPeripheral

    public init(id: String, name: String, rssi: Int, isFlypad: Bool, peripheral: CBPeripheral) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.isFlypad = isFlypad
        self.peripheral = peripheral
    }

    public static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        return lhs.id == rhs.id && lhs.rssi == rhs.rssi && lhs.name == rhs.name
    }
}

public enum BLEConnectionState: Equatable, Sendable {
    case disconnected
    case scanning
    case connecting(String)
    case discoveringServices(String)
    case ready(name: String, id: String)
    case error(String)
}

@MainActor
public final class FlypadBLEManager: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.example.FlypadDriverMac", category: "BLEManager")

    public static let flypadServiceUUID = CBUUID(string: "9A66FA00-0800-9191-11E4-012D1540CB8E")
    public static let batteryServiceUUID = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")
    public static let hidServiceUUID = CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")
    public static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")

    @Published public private(set) var connectionState: BLEConnectionState = .disconnected
    @Published public private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published public private(set) var latestTelemetry = FlypadTelemetry()
    @Published public private(set) var packetsPerSecond: Int = 0
    @Published public var showOnlyFlypadDevices: Bool = true

    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var packetCount = 0
    private var lastPacketTimestamp: Date?
    private var noPacketSeconds = 0
    private var rateTimer: Timer?
    private let autoConnectKey = "LastConnectedFlypadUUID"

    public override init() {
        super.init()
        log("Initializing FlypadBLEManager")
        self.centralManager = CBCentralManager(delegate: nil, queue: .main)
        self.centralManager.delegate = self
        startRateTimer()
    }

    public func startScan() {
        log("startScan requested. Central state: \(centralManager.state.rawValue)")
        guard centralManager.state == .poweredOn else {
            let errMsg = "Bluetooth power state is \(centralManager.state.rawValue) (not poweredOn)"
            logError(errMsg)
            connectionState = .error(errMsg)
            return
        }

        discoveredDevices.removeAll()
        connectionState = .scanning
        log("Starting centralManager scanForPeripherals...")
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func stopScan() {
        log("stopScan requested")
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    public func connect(device: DiscoveredDevice) {
        log("connect requested for '\(device.name)' (UUID: \(device.id))")
        stopScan()

        connectionState = .connecting(device.name)
        activePeripheral = device.peripheral
        activePeripheral?.delegate = self

        log("Calling centralManager.connect for peripheral \(device.id)...")
        centralManager.connect(device.peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])

        UserDefaults.standard.set(device.id, forKey: autoConnectKey)
    }

    public func disconnect() {
        log("disconnect requested")
        if let peripheral = activePeripheral {
            log("Cancelling peripheral connection for '\(peripheral.name ?? "unnamed")' (\(peripheral.identifier.uuidString))")
            centralManager.cancelPeripheralConnection(peripheral)
        }
        activePeripheral = nil
        lastPacketTimestamp = nil
        noPacketSeconds = 0
        connectionState = .disconnected
    }

    private func attemptAutoReconnect() {
        if let savedUUIDStr = UserDefaults.standard.string(forKey: autoConnectKey),
           let uuid = UUID(uuidString: savedUUIDStr) {
            log("Attempting auto-reconnect for saved UUID: \(savedUUIDStr)")
            let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let target = knownPeripherals.first {
                log("Found cached peripheral '\(target.name ?? "Flypad")'. Connecting...")
                connectionState = .connecting(target.name ?? "Flypad")
                activePeripheral = target
                activePeripheral?.delegate = self
                centralManager.connect(target, options: [
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
                ])
                return
            }
        }

        log("No cached peripheral found or first run. Starting scan to auto-connect nearby Flypad...")
        startScan()
    }

    private func startRateTimer() {
        rateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.packetsPerSecond = self.packetCount
                self.packetCount = 0

                // 1. Check if activePeripheral hardware state changed
                if let peripheral = self.activePeripheral {
                    if peripheral.state == .disconnected {
                        self.log("Active peripheral state is .disconnected. Updating connection state...")
                        self.connectionState = .disconnected
                        self.activePeripheral = nil
                        return
                    }
                }

                // 2. Watchdog for sudden power off / battery loss
                if case .ready = self.connectionState {
                    if let lastTime = self.lastPacketTimestamp {
                        let secondsSinceLastPacket = Date().timeIntervalSince(lastTime)
                        if secondsSinceLastPacket > 3.0 {
                            self.noPacketSeconds += 1
                            if self.noPacketSeconds >= 3 {
                                self.log("Watchdog: Packet stream idle for \(Int(secondsSinceLastPacket))s. Flypad is powered off or out of range. Disconnecting...")
                                self.disconnect()
                            }
                        } else {
                            self.noPacketSeconds = 0
                        }
                    }
                }
            }
        }
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        print("[FlypadBLE] \(message)")
    }

    private func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        print("[FlypadBLE ERROR] \(message)")
    }
}

extension FlypadBLEManager: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.log("Central manager updated state: \(central.state.rawValue)")
            if central.state == .poweredOn {
                self.attemptAutoReconnect()
            } else {
                self.connectionState = .error("Bluetooth state: \(central.state.rawValue)")
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        let isFlypad = name.localizedCaseInsensitiveContains("flypad") ||
                       name.localizedCaseInsensitiveContains("parrot") ||
                       name.localizedCaseInsensitiveContains("minidrone")

        let device = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: RSSI.intValue,
            isFlypad: isFlypad,
            peripheral: peripheral
        )

        Task { @MainActor in
            if self.showOnlyFlypadDevices && !isFlypad {
                return
            }

            if let idx = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[idx] = device
            } else {
                self.log("Discovered device: name='\(name)', isFlypad=\(isFlypad), id=\(peripheral.identifier.uuidString), rssi=\(RSSI.intValue)dBm")
                self.discoveredDevices.append(device)
                self.discoveredDevices.sort { ($0.isFlypad ? 1 : 0) > ($1.isFlypad ? 1 : 0) }
            }

            // Auto-connect to Flypad when powered on
            if isFlypad && (self.connectionState == .scanning || self.connectionState == .disconnected) {
                let savedUUID = UserDefaults.standard.string(forKey: self.autoConnectKey)
                if savedUUID == nil || savedUUID == device.id {
                    self.log("Auto-connecting to powered-on Flypad '\(name)' (\(device.id))...")
                    self.connect(device: device)
                }
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let name = peripheral.name ?? "Flypad"
            self.log("CONNECTED to GATT server: '\(name)' (\(peripheral.identifier.uuidString))")
            self.connectionState = .discoveringServices(name)

            peripheral.delegate = self
            self.log("Discovering ALL GATT services on '\(name)'...")
            peripheral.discoverServices(nil)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            let errStr = error?.localizedDescription ?? "Unknown GATT error"
            self.logError("FAILED to connect to peripheral '\(peripheral.name ?? "unnamed")': \(errStr)")
            self.connectionState = .error("Connection failed: \(errStr)")
            self.activePeripheral = nil
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if let err = error {
                self.logError("DISCONNECTED peripheral '\(peripheral.name ?? "unnamed")' with error: \(err.localizedDescription)")
                self.connectionState = .error("Disconnected with error: \(err.localizedDescription)")
            } else {
                self.log("DISCONNECTED peripheral '\(peripheral.name ?? "unnamed")' cleanly.")
                self.connectionState = .disconnected
            }
            self.activePeripheral = nil
            self.lastPacketTimestamp = nil
            self.noPacketSeconds = 0
        }
    }
}

extension FlypadBLEManager: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let err = error {
                self.logError("Service discovery failed for '\(peripheral.name ?? "unnamed")': \(err.localizedDescription)")
                self.connectionState = .error("Service discovery failed: \(err.localizedDescription)")
                return
            }

            guard let services = peripheral.services, !services.isEmpty else {
                self.logError("No GATT services discovered on '\(peripheral.name ?? "unnamed")'")
                self.connectionState = .error("No GATT services found")
                return
            }

            let name = peripheral.name ?? "Flypad"
            self.log("Discovered \(services.count) GATT service(s) on '\(name)': \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")

            self.connectionState = .ready(name: name, id: peripheral.identifier.uuidString)

            for service in services {
                self.log("Discovering characteristics for service: \(service.uuid.uuidString)...")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let err = error {
                self.logError("Characteristic discovery failed for service '\(service.uuid.uuidString)': \(err.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else { return }
            self.log("Discovered \(characteristics.count) characteristic(s) in service '\(service.uuid.uuidString)'")

            for characteristic in characteristics {
                let props = characteristic.properties
                self.log("Characteristic UUID: \(characteristic.uuid.uuidString) | Properties: \(props.rawValue)")

                if props.contains(.notify) || props.contains(.indicate) {
                    self.log("Enabling notifications on characteristic \(characteristic.uuid.uuidString)...")
                    peripheral.setNotifyValue(true, for: characteristic)
                }

                if props.contains(.read) {
                    self.log("Reading initial value for characteristic \(characteristic.uuid.uuidString)...")
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let err = error {
                self.logError("Failed to change notification state for \(characteristic.uuid.uuidString): \(err.localizedDescription)")
            } else {
                self.log("Notification state set to \(characteristic.isNotifying) for characteristic \(characteristic.uuid.uuidString)")
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let err = error {
                self.logError("Error updating value for characteristic \(characteristic.uuid.uuidString): \(err.localizedDescription)")
                return
            }

            guard let data = characteristic.value else { return }

            self.packetCount += 1
            self.lastPacketTimestamp = Date()
            self.noPacketSeconds = 0

            // Check for Battery Service characteristic (0x2A19) or single byte battery update
            if characteristic.uuid == Self.batteryLevelCharacteristicUUID || (data.count == 1 && characteristic.uuid.uuidString.contains("2A19")) {
                let batteryVal = Int(data[0])
                if (0...100).contains(batteryVal) {
                    self.latestTelemetry.batteryLevel = batteryVal
                    self.log("Battery status report received from 2A19: \(batteryVal)%")
                    return
                }
            }

            if self.packetCount == 1 {
                let hexStr = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                self.log("First telemetry packet received from \(characteristic.uuid.uuidString) [\(data.count) bytes]: \(hexStr)")
            }

            var parsed = FlypadTelemetryParser.parse(data)
            if parsed.batteryLevel < 0 && self.latestTelemetry.batteryLevel >= 0 {
                parsed.batteryLevel = self.latestTelemetry.batteryLevel
            }
            self.latestTelemetry = parsed
        }
    }
}
