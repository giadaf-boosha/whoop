import CoreBluetooth
import Foundation
import WhoopProtocol

/// Connection lifecycle of the strap, surfaced to the UI.
enum WhoopConnection: Equatable {
    case bluetoothOff
    case unauthorized
    case scanning
    case connecting
    case handshaking
    case ready
    case disconnected
}

/// Manages the BLE link to a WHOOP 5.0 / MG strap and sends the haptic buzz.
///
/// Lifecycle: scan by service UUID → connect → discover → write CLIENT_HELLO
/// (confirmed) → enable notifications → ready. The central is created with a
/// restore identifier so iOS can relaunch the app and hand the connection back
/// after a background BLE event.
final class WhoopBLEManager: NSObject, ObservableObject {
    @Published private(set) var connection: WhoopConnection = .disconnected
    @Published private(set) var deviceName: String?
    @Published private(set) var lastBuzzAcked: Bool = false
    /// Number of BLE peripherals seen during the current scan — a diagnostic that
    /// distinguishes "scan blocked / nothing advertising" (0) from "saw devices but
    /// none was a WHOOP" (>0).
    @Published private(set) var scannedCount: Int = 0

    private var central: CBCentralManager!
    private var strap: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var seq: UInt8 = 0
    private var watchdog: Timer?

    private let serviceUUID = CBUUID(string: Whoop.serviceUUID)
    private let commandUUID = CBUUID(string: Whoop.commandWriteUUID)
    private let notifyUUIDs = Set(Whoop.notifyUUIDs.map { CBUUID(string: $0) })
    private let restoreID = "com.boosha.whoopbuzz.central"

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: restoreID]
        )
        // Re-check the connection regularly and recover from any drop (out of range,
        // strap on charger, the official WHOOP app stealing it) without user action.
        watchdog = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            self?.ensureConnected()
        }
    }

    /// Make sure we are connected or actively trying to be. Called by the watchdog.
    private func ensureConnected() {
        guard central?.state == .poweredOn else { return }
        switch connection {
        case .ready, .connecting, .handshaking:
            return
        default:
            if let strap {
                connection = .connecting
                central.connect(strap)
            } else {
                start()
            }
        }
    }

    /// Begin discovery if Bluetooth is ready and we are not already connected.
    ///
    /// Two-pronged because the strap may not be discoverable by a plain scan:
    /// 1. If it is already connected to the system (e.g. the official WHOOP app
    ///    holds it), it has stopped advertising — only `retrieveConnectedPeripherals`
    ///    can recover it.
    /// 2. Otherwise scan for *all* peripherals and match by name. The strap does not
    ///    reliably put its 128-bit service UUID in the advertising packet, so a
    ///    service-filtered scan misses it; the reference implementation matches on the
    ///    "WHOOP" name prefix instead (see docs/ble-protocol-research.md §5).
    func start() {
        guard central.state == .poweredOn else { return }
        guard strap == nil else { return }

        if let existing = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first {
            connectTo(existing)
            return
        }

        scannedCount = 0
        connection = .scanning
        central.scanForPeripherals(withServices: nil)
    }

    private func connectTo(_ peripheral: CBPeripheral) {
        central.stopScan()
        strap = peripheral
        deviceName = peripheral.name
        peripheral.delegate = self
        connection = .connecting
        central.connect(peripheral)
    }

    /// How many times the strap repeats the waveform per command. 6 is a value
    /// confirmed accepted on real hardware; higher values (e.g. 15) are rejected by
    /// the firmware and produce no buzz at all, so length comes from `buzzRepeats`
    /// (whole commands chained) rather than from pushing this byte too high.
    private let buzzLoops: UInt8 = 6

    /// Number of commands fired per buzz and their spacing — chained back-to-back so
    /// the looped haptic plays as one long, sustained buzz, with redundancy in case a
    /// write is lost amid the incoming-call moment.
    private let buzzRepeats = 7
    private let buzzRepeatInterval: TimeInterval = 1.1

    /// Fire the strong, sustained looped haptic. Safe to call when not ready (no-op).
    func buzz() {
        guard connection == .ready else { return }
        lastBuzzAcked = false
        for i in 0..<buzzRepeats {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * buzzRepeatInterval) { [weak self] in
                self?.sendOnePulse()
            }
        }
    }

    private func sendOnePulse() {
        guard let strap, let commandChar, connection == .ready else { return }
        seq &+= 1
        strap.writeValue(Data(WhoopFrame.buzz(seq: seq, loops: buzzLoops)), for: commandChar, type: .withoutResponse)
    }

    private func sendClientHello() {
        guard let strap, let commandChar else { return }
        connection = .handshaking
        strap.writeValue(Data(Whoop.clientHello), for: commandChar, type: .withResponse)
    }
}

extension WhoopBLEManager: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restored = peripherals.first {
            strap = restored
            restored.delegate = self
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let strap, strap.state != .connected {
                connection = .connecting
                central.connect(strap)
            } else if strap == nil {
                start()
            }
        case .poweredOff:
            connection = .bluetoothOff
        case .unauthorized:
            connection = .unauthorized
        default:
            connection = .disconnected
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        scannedCount += 1
        let advName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        guard advName.uppercased().hasPrefix("WHOOP") else { return }
        connectTo(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        commandChar = nil
        connection = .disconnected
        // Keep the strap reference and reconnect; iOS holds this pending in the
        // background and resumes when the strap is back in range.
        central.connect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connection = .disconnected
        central.connect(peripheral)
    }
}

extension WhoopBLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        for char in service.characteristics ?? [] {
            if char.uuid == commandUUID {
                commandChar = char
            } else if notifyUUIDs.contains(char.uuid), char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
        }
        if commandChar != nil {
            sendClientHello()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        // The only confirmed write we issue is the CLIENT_HELLO; its ack means the
        // encrypted session is open and the strap will accept commands.
        if characteristic.uuid == commandUUID, error == nil {
            connection = .ready
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let value = characteristic.value else { return }
        if WhoopFrame.responseCommand([UInt8](value)) == Whoop.hapticCommand {
            lastBuzzAcked = true
        }
    }
}
