import Network
import XCTest

/// A UDP listener on the loopback interface, standing in for UFeel.
private final class UDPReceiver: @unchecked Sendable {
    let listener: NWListener
    private let queue = DispatchQueue(label: "UFeel.UDPReceiverTests")
    private let onPacket: @Sendable (String) -> Void

    init(onPacket: @escaping @Sendable (String) -> Void) throws {
        let parameters = NWParameters.udp
        parameters.requiredInterfaceType = .loopback
        listener = try NWListener(using: parameters, on: .any)
        self.onPacket = onPacket
    }

    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, Error>) in
            let resumed = NSLock()
            nonisolated(unsafe) var done = false
            listener.stateUpdateHandler = { [listener] state in
                resumed.lock()
                defer { resumed.unlock() }
                guard !done else {
                    return
                }
                switch state {
                case .ready:
                    done = true
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case let .failed(error):
                    done = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [queue, onPacket] connection in
                connection.start(queue: queue)
                Self.receive(on: connection, onPacket: onPacket)
            }
            listener.start(queue: queue)
        }
    }

    private static func receive(
        on connection: NWConnection,
        onPacket: @escaping @Sendable (String) -> Void
    ) {
        connection.receiveMessage { data, _, _, error in
            if let data {
                onPacket(String(decoding: data, as: UTF8.self))
            }
            if error == nil {
                receive(on: connection, onPacket: onPacket)
            }
        }
    }

    func stop() {
        listener.cancel()
    }
}

final class UDPSenderTests: XCTestCase {
    func testSendsEachBpmAsTheTextUFeelReads() async throws {
        let received = expectation(description: "packets received")
        received.expectedFulfillmentCount = 2
        let packets = PacketLog()
        let receiver = try UDPReceiver { packet in
            packets.append(packet)
            received.fulfill()
        }
        let port = try await receiver.start()
        defer { receiver.stop() }

        let sender = UDPSender()
        sender.setDestination(host: "127.0.0.1", port: port)
        sender.send(HeartRateMessage.packet(bpm: 72))
        sender.send(HeartRateMessage.packet(bpm: 75))

        await fulfillment(of: [received], timeout: 5)
        XCTAssertEqual(packets.values, ["72", "75"])
    }

    func testFailsWithoutADestination() async {
        let sender = UDPSender()
        sender.setDestination(host: " ", port: 9999)

        let error = await withCheckedContinuation { continuation in
            sender.send(HeartRateMessage.packet(bpm: 72)) { error in
                continuation.resume(returning: error)
            }
        }

        XCTAssertTrue(error is UDPSenderError)
    }
}

final class HeartRateRelayTests: XCTestCase {
    func testExplainsThatUFeelIsNotListeningWhenThePortRefusesPackets() {
        XCTAssertEqual(
            HeartRateRelay.describe(NWError.posix(.ECONNREFUSED)),
            "UFeel is not listening on this computer and port yet."
        )
        XCTAssertEqual(
            HeartRateRelay.describe(UDPSenderError.noDestination),
            UDPSenderError.noDestination.localizedDescription
        )
    }
}

private final class PacketLog: @unchecked Sendable {
    private let lock = NSLock()
    private var packets: [String] = []

    var values: [String] {
        lock.withLock { packets }
    }

    func append(_ packet: String) {
        lock.withLock { packets.append(packet) }
    }
}
