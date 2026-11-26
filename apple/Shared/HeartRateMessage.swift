import Foundation

/// The heart rate as the watch sends it to the iPhone, and as the iPhone sends it to UFeel.
enum HeartRateMessage {
    /// WatchConnectivity message key holding the BPM.
    static let key = "bpm"

    /// The readings UFeel accepts, in BPM.
    static let validRange = 20...250

    static func message(bpm: Int) -> [String: Any] {
        [key: bpm]
    }

    /// The BPM of a watch message, or nil when it holds none that UFeel accepts.
    static func bpm(from message: [String: Any]) -> Int? {
        guard let bpm = message[key] as? Int, validRange.contains(bpm) else {
            return nil
        }
        return bpm
    }

    /// The UDP packet UFeel reads: the BPM as plain text, such as "72", like the Wear OS app sends.
    static func packet(bpm: Int) -> Data {
        Data(String(bpm).utf8)
    }
}
