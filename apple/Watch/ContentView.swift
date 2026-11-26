import SwiftUI

struct ContentView: View {
    let workout: HeartRateWorkout

    var body: some View {
        VStack(spacing: 6) {
            Text(workout.bpm.map(String.init) ?? "--")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("BPM")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(workout.isRunning ? "Stop" : "Start") {
                Task {
                    if workout.isRunning {
                        await workout.stop()
                    } else {
                        await workout.start()
                    }
                }
            }
            .tint(workout.isRunning ? .red : .green)

            Text(status)
                .font(.footnote)
                .foregroundStyle(workout.errorMessage == nil ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
        }
    }

    private var status: String {
        if let error = workout.errorMessage {
            return error
        }
        return workout.phoneReachable ? "iPhone connected" : "Open UFeel on your iPhone"
    }
}
