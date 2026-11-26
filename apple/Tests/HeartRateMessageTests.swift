import XCTest

final class HeartRateMessageTests: XCTestCase {
    func testPacketIsTheBpmAsPlainText() {
        XCTAssertEqual(String(decoding: HeartRateMessage.packet(bpm: 72), as: UTF8.self), "72")
        XCTAssertEqual(String(decoding: HeartRateMessage.packet(bpm: 180), as: UTF8.self), "180")
    }

    func testReadsTheBpmOfAWatchMessage() {
        XCTAssertEqual(HeartRateMessage.bpm(from: HeartRateMessage.message(bpm: 72)), 72)
    }

    func testRejectsMessagesWithoutAnAcceptedBpm() {
        XCTAssertNil(HeartRateMessage.bpm(from: [:]))
        XCTAssertNil(HeartRateMessage.bpm(from: [HeartRateMessage.key: "72"]))
        XCTAssertNil(HeartRateMessage.bpm(from: HeartRateMessage.message(bpm: 19)))
        XCTAssertNil(HeartRateMessage.bpm(from: HeartRateMessage.message(bpm: 251)))
        XCTAssertEqual(HeartRateMessage.bpm(from: HeartRateMessage.message(bpm: 20)), 20)
        XCTAssertEqual(HeartRateMessage.bpm(from: HeartRateMessage.message(bpm: 250)), 250)
    }
}
