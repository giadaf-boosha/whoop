import Foundation

/// BLE identifiers and command bytes for the WHOOP 5.0 / MG ("puffin"/"maverick") strap.
///
/// Every value here is documented and hardware-verified in `NoopApp/noop`
/// (`DeviceFamily.swift`, `whoop_frame.py`, `docs/PROTOCOL.md`). The WHOOP 4.0
/// strap uses a different service and a different haptic opcode and is out of
/// scope for this app — see `docs/ble-protocol-research.md`.
public enum Whoop {
    /// Custom GATT service exposed by the WHOOP 5.0 / MG strap.
    public static let serviceUUID = "fd4b0001-cce1-4033-93ce-002d5875f58a"

    /// Characteristic the app writes commands to (CLIENT_HELLO, buzz).
    public static let commandWriteUUID = "fd4b0002-cce1-4033-93ce-002d5875f58a"

    /// Notify characteristics the strap streams responses on. `…0007` is the
    /// command-response channel that acknowledges a haptic.
    public static let notifyUUIDs = [
        "fd4b0003-cce1-4033-93ce-002d5875f58a",
        "fd4b0004-cce1-4033-93ce-002d5875f58a",
        "fd4b0005-cce1-4033-93ce-002d5875f58a",
        "fd4b0007-cce1-4033-93ce-002d5875f58a",
    ]

    /// Static 16-byte CLIENT_HELLO. Written (confirmed) to the command
    /// characteristic immediately after GATT discovery to open the encrypted
    /// puffin session; without it, subsequent command writes hang.
    public static let clientHello: [UInt8] = [
        0xAA, 0x01, 0x08, 0x00, 0x00, 0x01, 0xE6, 0x71,
        0x23, 0x01, 0x91, 0x01, 0x36, 0x3E, 0x5C, 0x8D,
    ]

    /// `RUN_HAPTIC_PATTERN_MAVERICK`. The WHOOP 5/MG strap rejects the 4.0
    /// opcode 79 with result 0x03; this is the opcode the official app uses.
    public static let hapticCommand: UInt8 = 0x13

    /// COMMAND packet type byte (PacketType.COMMAND).
    public static let commandType: UInt8 = 35

    /// COMMAND_RESPONSE packet type byte — the strap's per-command ack.
    public static let commandResponseType: UInt8 = 36

    /// 12-byte "notify" haptic preset (the gentle notification buzz), matched
    /// byte-for-byte to the official app: `[REVISION_1, effects…, loopControl, overallLoop]`.
    public static let hapticNotifyBody: [UInt8] = [0x01, 47, 152, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}
