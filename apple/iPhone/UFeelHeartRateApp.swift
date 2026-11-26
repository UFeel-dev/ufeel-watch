import SwiftUI

@main
struct UFeelHeartRateApp: App {
    @State private var relay = HeartRateRelay()

    var body: some Scene {
        WindowGroup {
            ContentView(relay: relay)
                .onAppear { relay.activate() }
        }
    }
}
