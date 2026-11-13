import SwiftUI

@main
struct FlypadDriverMacApp: App {
    var body: some Scene {
        WindowGroup("Flypad Driver - https://pairhint.com | https://castmypitch.com") {
            MainView()
                .frame(minWidth: 920, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
