# Project Plan

Flypad Driver for macOS: Native macOS gamepad driver app that connects to Flypad controllers via Bluetooth (CoreBluetooth), decodes stick and button inputs, creates a virtual gamepad on macOS via GCVirtualController / IOHID, and provides a macOS GUI for pairing, key remapping, and live input testing.

## Project Brief

# Project Brief: macOS Flypad Gamepad Driver

## Features

1. **Bluetooth LE Device Management & Auto-Connect**: Wirelessly scans for, connects to, and automatically re-pairs with Parrot Flypad controllers using native macOS Bluetooth capabilities.
2. **Virtual Gamepad Input Emulation**: Decodes raw Bluetooth telemetry packets from the Flypad and exposes them as a standard system-recognized gamepad via `GCVirtualController` (or IOHID), enabling seamless plug-and-play compatibility with macOS games and applications.
3. **Live Input Visualizer**: Displays a real-time visual representation of analog stick coordinates, button states, and trigger pressure levels for input testing and latency diagnostics.
4. **Button & Axis Remapping**: Provides custom key rebinding, stick axis inversion, and deadzone adjustment controls to tailor input mapping per game or user preference.

## High-Level Technical Stack

- **Language**: Swift 5+
- **UI Framework**: SwiftUI (Native macOS Dark/Light Mode interface)
- **Bluetooth Communication**: CoreBluetooth Framework
- **Virtual Controller Integration**: GameController Framework (`GCVirtualController`) / IOHIDManager
- **Concurrency & State Management**: Swift Concurrency (`async`/`await`, `Actors`) & Combine

## Implementation Steps
**Total Duration:** 23m 34s

### Task_1_Bluetooth_Driver_Service: Implement Bluetooth BLE connection manager and Parrot controller discovery service to scan, pair, and receive raw telemetry notifications from Parrot controllers.
- **Status:** COMPLETED
- **Updates:** Implemented Parrot BLE manager, scanning, connection state flow, UUID subscription, and telemetry byte parsing for Parrot Flypad and Skycontroller. Unit tests passed and project built cleanly.
- **Acceptance Criteria:**
  - BLE scanning and connection logic implemented for Parrot controllers
  - Raw input telemetry streams received via BluetoothGatt notifications
  - build pass
- **Duration:** 5m

### Task_2_Input_Parsing_Mapping_Engine: Implement input data parser and mapping engine to decode Parrot telemetry bytes into analog joystick axes and digital button states with configurable remapping support.
- **Status:** COMPLETED
- **Updates:** Implemented input mapping models (GamepadAxis, GamepadButton, GamepadMappingProfile), InputMappingEngine with deadzones/inversion/curves/presets, and MappingRepository backed by DataStore. 17 unit tests passed and project built cleanly.
- **Acceptance Criteria:**
  - Raw byte streams decoded into joystick axes and button states
  - Configurable key/axis remapping repository implemented
  - build pass
- **Duration:** 5m 59s

### Task_3_UI_Screens_And_Visualizer: Build Jetpack Compose screens for Bluetooth device scanning/connection status, custom key & axis mapping configuration, and live input visualizer test tool.
- **Status:** COMPLETED
- **Updates:** Built Jetpack Compose screens (ScannerScreen, VisualizerScreen, MappingScreen), App Shell with Nav3, ViewModels, and UI tests. 26 unit tests passed and project built cleanly.
- **Acceptance Criteria:**
  - Compose UI screens built for scanner, remapping config, and live input tester
  - Real-time visual feedback for stick positions, trigger pressures, and button presses
  - build pass
- **Duration:** 12m 35s

### Task_4_Run_And_Verify: Run and verify application stability, instruct critic_agent to verify application stability (no crashes), confirm alignment with user requirements, and report critical UI issues.
- **Status:** IN_PROGRESS
- **Acceptance Criteria:**
  - make sure all existing tests pass
  - build pass
  - app does not crash
  - Parrot controller connectivity, remapping UI, and input visualizer verified
- **StartTime:** 2026-11-13 07:06:46 CET

