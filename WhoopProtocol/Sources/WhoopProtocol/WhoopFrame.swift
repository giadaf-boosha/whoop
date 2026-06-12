import Foundation

/// Builds and validates WHOOP 5.0 / MG ("puffin") BLE command frames.
///
/// Envelope (port of `puffinCommandFrame` / `build_puffin_command`):
/// ```
/// [0xAA][format=0x01][declLength u16 LE][header u16][crc16 u16 LE][type][seq][cmd][payload…][crc32 u32 LE]
/// ```
/// `declLength` = inner length + 4; the inner record starts at offset 8; CRC16
/// covers the first 6 bytes; CRC32 covers the inner record. The 16-byte
/// `Whoop.clientHello` is itself a valid frame of this form and is used as a
/// golden vector in the tests.
public enum WhoopFrame {
    /// Build a complete puffin COMMAND frame.
    public static func puffinCommand(
        cmd: UInt8,
        seq: UInt8 = 0,
        payload: [UInt8] = [0x00],
        type: UInt8 = Whoop.commandType,
        header: [UInt8] = [0x00, 0x01]
    ) -> [UInt8] {
        let inner = [type, seq, cmd] + payload
        let decl = inner.count + 4

        var frame: [UInt8] = [0xAA, 0x01, UInt8(decl & 0xFF), UInt8((decl >> 8) & 0xFF), header[0], header[1]]

        let c16 = Crc.crc16Modbus(Array(frame[0..<6]))
        frame += [UInt8(c16 & 0xFF), UInt8((c16 >> 8) & 0xFF)]

        frame += inner

        let c32 = Crc.crc32(inner)
        frame += [
            UInt8(c32 & 0xFF),
            UInt8((c32 >> 8) & 0xFF),
            UInt8((c32 >> 16) & 0xFF),
            UInt8((c32 >> 24) & 0xFF),
        ]
        return frame
    }

    /// Right-pad a command body with zeros so the inner record (type+seq+cmd+payload)
    /// lands on a 4-byte boundary. The strap rejects a non-aligned haptic body.
    static func pad4(_ payload: [UInt8]) -> [UInt8] {
        let innerLen = 3 + payload.count
        let pad = (4 - innerLen % 4) % 4
        return payload + [UInt8](repeating: 0, count: pad)
    }

    /// The WHOOP 5 / MG "notify" buzz frame: maverick haptic (opcode 0x13),
    /// puffin-framed and pad4'd. This is the single command this app sends.
    ///
    /// `loops` is the body's last byte — the `overallWaveformLoopControl` — which
    /// tells the strap how many times to repeat the waveform on its own. A higher
    /// value yields a longer, stronger buzz from a single write, so the buzz does not
    /// depend on the app firing multiple commands with precise timing (which is
    /// unreliable during an incoming call). The documented single-execution value is 1.
    public static func buzz(seq: UInt8 = 0, loops: UInt8 = 1) -> [UInt8] {
        var body = Whoop.hapticNotifyBody
        body[body.count - 1] = loops
        return puffinCommand(cmd: Whoop.hapticCommand, seq: seq, payload: pad4(body))
    }

    /// True if a frame's declared length, CRC16 header and CRC32 trailer all check out.
    public static func isValid(_ frame: [UInt8]) -> Bool {
        guard frame.count >= 12, frame[0] == 0xAA else { return false }
        let decl = Int(frame[2]) | (Int(frame[3]) << 8)
        let total = decl + 8
        guard total == frame.count else { return false }
        guard Crc.crc16Modbus(Array(frame[0..<6])) == UInt16(frame[6]) | (UInt16(frame[7]) << 8) else { return false }
        let inner = Array(frame[8..<(total - 4)])
        let wire = UInt32(frame[total - 4]) | (UInt32(frame[total - 3]) << 8)
            | (UInt32(frame[total - 2]) << 16) | (UInt32(frame[total - 1]) << 24)
        return Crc.crc32(inner) == wire
    }

    /// If `frame` is a COMMAND_RESPONSE (type 36), return the command number it
    /// acknowledges, else nil. Lets the BLE layer confirm the strap accepted the
    /// haptic (`responseCommand(frame) == Whoop.hapticCommand`).
    public static func responseCommand(_ frame: [UInt8]) -> UInt8? {
        let innerOffset = 8
        guard frame.count >= innerOffset + 3, frame[0] == 0xAA else { return nil }
        guard frame[innerOffset] == Whoop.commandResponseType else { return nil }
        return frame[innerOffset + 2]
    }
}
