import XCTest
@testable import WhoopProtocol

final class WhoopFrameTests: XCTestCase {

    // MARK: CRC against published catalogue check values ("123456789")

    func testCrc16ModbusCheckValue() {
        let input = Array("123456789".utf8)
        XCTAssertEqual(Crc.crc16Modbus(input), 0x4B37)
    }

    func testCrc32ZlibCheckValue() {
        let input = Array("123456789".utf8)
        XCTAssertEqual(Crc.crc32(input), 0xCBF4_3926)
    }

    // MARK: Golden frame — the static CLIENT_HELLO is itself a valid puffin frame.
    // Reproducing it byte-for-byte proves the whole pipeline (header, CRC16, inner,
    // CRC32) is correct without any hardware.

    func testClientHelloIsReproducedFromBuilder() {
        let built = WhoopFrame.puffinCommand(cmd: 0x91, seq: 0x01, payload: [0x01])
        XCTAssertEqual(built, Whoop.clientHello)
    }

    func testClientHelloPassesSelfValidation() {
        XCTAssertTrue(WhoopFrame.isValid(Whoop.clientHello))
    }

    // MARK: Buzz frame

    func testBuzzFrameStructure() {
        let frame = WhoopFrame.buzz(seq: 0)
        // 12-byte body → pad4 adds 1 → inner = 3 + 13 = 16 → declLength = 20 → total = 28.
        XCTAssertEqual(frame.count, 28)
        XCTAssertEqual(frame[0], 0xAA)
        XCTAssertEqual(frame[1], 0x01)
        XCTAssertEqual(frame[8], Whoop.commandType)        // inner type
        XCTAssertEqual(frame[10], Whoop.hapticCommand)     // inner cmd == 0x13
        XCTAssertTrue(WhoopFrame.isValid(frame))
    }

    func testPad4AlignsInnerRecord() {
        let padded = WhoopFrame.pad4(Whoop.hapticNotifyBody)
        XCTAssertEqual((3 + padded.count) % 4, 0)
    }

    func testSeqIsCarriedIntoFrame() {
        let frame = WhoopFrame.buzz(seq: 0x2A)
        XCTAssertEqual(frame[9], 0x2A)                     // inner seq
        XCTAssertTrue(WhoopFrame.isValid(frame))
    }

    // MARK: Validation rejects corruption

    func testIsValidRejectsFlippedByte() {
        var frame = WhoopFrame.buzz(seq: 0)
        frame[12] ^= 0xFF                                  // corrupt a payload byte
        XCTAssertFalse(WhoopFrame.isValid(frame))
    }

    func testResponseCommandDetectsHapticAck() {
        // A COMMAND_RESPONSE (type 36) echoing the haptic opcode at inner cmd.
        let ack = WhoopFrame.puffinCommand(
            cmd: Whoop.hapticCommand, payload: [0x00], type: Whoop.commandResponseType
        )
        XCTAssertEqual(WhoopFrame.responseCommand(ack), Whoop.hapticCommand)
        XCTAssertNil(WhoopFrame.responseCommand(WhoopFrame.buzz()))  // a COMMAND, not a response
    }
}
