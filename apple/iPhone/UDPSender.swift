import Foundation
import Network

/// Sends packets to one UDP destination, reusing the connection until the destination changes.
///
/// Thread-safe: every call runs on a private serial queue, so packets can be sent straight from the
/// WatchConnectivity delegate, even while the app only runs in the background to receive them.
final class UDPSender: @unchecked Sendable {
    private let queue = DispatchQueue(label: "UFeel.UDPSender")
    private var endpoint: NWEndpoint?
    private var connection: NWConnection?

    /// Sets where the next packets go. An empty host or a zero port stops sending.
    func setDestination(host: String, port: UInt16) {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let destination: NWEndpoint? =
            if trimmedHost.isEmpty || port == 0 {
                nil
            } else {
                .hostPort(host: NWEndpoint.Host(trimmedHost), port: NWEndpoint.Port(rawValue: port)!)
            }
        queue.async {
            guard destination != self.endpoint else {
                return
            }
            self.connection?.cancel()
            self.connection = nil
            self.endpoint = destination
        }
    }

    /// Sends the packet, then calls `completion` with the error, if any, on the sender's queue.
    func send(_ packet: Data, completion: @escaping @Sendable (Error?) -> Void = { _ in }) {
        queue.async {
            guard let connection = self.currentConnection() else {
                completion(UDPSenderError.noDestination)
                return
            }
            connection.send(
                content: packet,
                completion: .contentProcessed { error in completion(error) }
            )
        }
    }

    private func currentConnection() -> NWConnection? {
        guard let endpoint else {
            return nil
        }
        if let connection {
            switch connection.state {
            case .failed, .cancelled:
                connection.cancel()
            default:
                return connection
            }
        }
        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: queue)
        self.connection = connection
        return connection
    }
}

enum UDPSenderError: LocalizedError {
    case noDestination

    var errorDescription: String? {
        "Enter the IP address of the computer running UFeel."
    }
}
