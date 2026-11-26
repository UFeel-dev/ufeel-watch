import Foundation
import Network
import Observation
import WatchConnectivity

/// Forwards each BPM the watch sends to UFeel, as a UDP packet to the computer's port.
@MainActor
@Observable
final class HeartRateRelay: NSObject {
    static let defaultPort = 9999

    /// IP address of the computer running UFeel. Broadcast would need an entitlement on iOS.
    var host: String {
        didSet {
            defaults.set(host, forKey: Keys.host)
            updateDestination()
        }
    }

    var port: Int {
        didSet {
            defaults.set(port, forKey: Keys.port)
            updateDestination()
        }
    }

    private(set) var lastBPM: Int?
    private(set) var lastError: String?
    private(set) var watchAppInstalled = false

    private enum Keys {
        static let host = "host"
        static let port = "port"
    }

    private let defaults: UserDefaults
    private let sender = UDPSender()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        host = defaults.string(forKey: Keys.host) ?? ""
        port = defaults.object(forKey: Keys.port) as? Int ?? Self.defaultPort
        super.init()
        updateDestination()
    }

    func activate() {
        guard WCSession.isSupported() else {
            lastError = "This iPhone does not support Apple Watch."
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func updateDestination() {
        let port = UInt16(exactly: port) ?? 0
        sender.setDestination(host: host, port: port)
    }

    private func didForward(bpm: Int, error: String?) {
        lastBPM = bpm
        lastError = error
    }

    /// Sends straight from the delegate queue, since the app may only run briefly in the
    /// background to receive the message.
    nonisolated private func forward(bpm: Int) {
        sender.send(HeartRateMessage.packet(bpm: bpm)) { error in
            let message = error.map(Self.describe)
            Task { @MainActor in
                self.didForward(bpm: bpm, error: message)
            }
        }
    }
}

extension HeartRateRelay {
    /// The computer refuses UDP packets on a port nothing listens to, for example before UFeel starts.
    nonisolated static func describe(_ error: Error) -> String {
        if case let .posix(code) = error as? NWError, code == .ECONNREFUSED {
            return "UFeel is not listening on this computer and port yet."
        }
        return error.localizedDescription
    }
}

extension HeartRateRelay: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let installed = session.isPaired && session.isWatchAppInstalled
        let message = error?.localizedDescription
        Task { @MainActor in
            self.watchAppInstalled = installed
            if let message {
                self.lastError = message
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isPaired && session.isWatchAppInstalled
        Task { @MainActor in
            self.watchAppInstalled = installed
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another watch: activate the session again for it.
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let bpm = HeartRateMessage.bpm(from: message) else {
            return
        }
        forward(bpm: bpm)
    }
}
