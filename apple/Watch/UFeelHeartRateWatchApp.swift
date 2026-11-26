import SwiftUI

@main
struct UFeelHeartRateWatchApp: App {
    @State private var workout = HeartRateWorkout()

    var body: some Scene {
        WindowGroup {
            ContentView(workout: workout)
        }
    }
}
