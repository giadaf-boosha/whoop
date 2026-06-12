import Foundation

/// CRC routines used by the WHOOP BLE framing.
///
/// Both are ported byte-for-byte from the hardware-verified reference in
/// `NoopApp/noop` (`tools/linux-capture/whoop_frame.py`). They are interoperability
/// facts about the WHOOP wire format, not application logic — see
/// `docs/ble-protocol-research.md` for the source trail.
enum Crc {
    /// CRC16-Modbus (poly 0xA001, init 0xFFFF, reflected). WHOOP 5.0 frame header check.
    static func crc16Modbus(_ data: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return crc
    }

    /// Standard zlib CRC-32 (poly 0xEDB88320, init/xor 0xFFFFFFFF, reflected).
    /// WHOOP 4.0/5.0 payload trailer.
    static func crc32(_ data: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
