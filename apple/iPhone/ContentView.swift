import SwiftUI

struct ContentView: View {
    @Bindable var relay: HeartRateRelay

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("IP address, such as 192.168.1.20", text: $relay.host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", value: $relay.port, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                } header: {
                    Text("Computer running UFeel")
                } footer: {
                    Text("Keep this iPhone on the same Wi-Fi as the computer.")
                }

                Section("Heart rate") {
                    LabeledContent("Last reading", value: lastReading)
                    if let error = relay.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text(watchStatus)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("UFeel Heart Rate")
        }
    }

    private var lastReading: String {
        relay.lastBPM.map { "\($0) BPM" } ?? "None yet"
    }

    private var watchStatus: String {
        relay.watchAppInstalled
            ? "Tap Start in the UFeel app on your Apple Watch."
            : "Install the UFeel app on your Apple Watch from the Watch app."
    }
}
