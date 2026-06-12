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
/// Lifecycle: discover → connect → discover services → write CLIENT_HELLO
/// (confirmed) → enable notifications → ready. Once ready, an 8-second heartbeat
/// (`readRSSI`) keeps the link warm and detects a stale link, because the strap
/// drops an idle connection if it sees no traffic (mirrors the keep-alive in the
/// NoopApp reference; see docs/ble-protocol-research.md §6).
final class WhoopBLEManager: NSObject, ObservableObject {
    @Published private(set) var connection: WhoopConnection = .disconnected
    @Published private(set) var deviceName: String?
    @Published private(set) var lastBuzzAcked: Bool = false
    /// Latest link signal strength (dBm) while connected — a diagnostic for range.
    @Published private(set) var rssi: Int?
    /// Number of BLE peripherals seen during the current scan — distinguishes
    /// "scan blocked / nothing advertising" (0) from "saw devices but no WHOOP" (>0).
    @Published private(set) var scannedCount: Int = 0

    private var central: CBCentralManager!
    private var strap: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var seq: UInt8 = 0
    private var watchdog: Timer?
    private var expectingHelloAck = false
    /// When we last saw any sign of life from the strap (write ack, notify, RSSI).
    private var lastSeenAt = Date()

    private let serviceUUID = CBUUID(string: Whoop.serviceUUID)
    private let commandUUID = CBUUID(string: Whoop.commandWriteUUID)
    private let notifyUUIDs = Set(Whoop.notifyUUIDs.map { CBUUID(string: $0) })
    private let restoreID = "com.boosha.whoopbuzz.central"
    private let staleAfter: TimeInterval = 30

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: restoreID]
        )
        watchdog = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Runs every 8s: keep the link alive when connected, recover it otherwise.
    private func tick() {
        guard central?.state == .poweredOn else { return }
        switch connection {
        case .ready:
            if Date().timeIntervalSince(lastSeenAt) > staleAfter {
                bounceLink()            // link is a zombie — force a clean reconnect
            } else {
                strap?.readRSSI()       // heartbeat: traffic keeps the strap from idling out
            }
        case .connecting, .handshaking:
            return
        default:
            ensureConnecting()
        }
    }

    private func ensureConnecting() {
        guard central?.state == .poweredOn else { return }
        if let strap {
            connection = .connecting
            central.connect(strap)
        } else {
            start()
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
    ///    service-filtered scan misses it (see docs/ble-protocol-research.md §5).
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
    /// the firmware and produce no buzz at all, so length comes from `buzzRepeats`.
    private let buzzLoops: UInt8 = 6
    /// Number of commands chained per buzz and their spacing — one long sustained buzz.
    private let buzzRepeats = 7
    private let buzzRepeatInterval: TimeInterval = 1.1

    /// Fire the strong, sustained looped haptic. If a call arrives mid-reconnect, keep
    /// retrying until the link is ready, up to a deadline (so we don't buzz for a call
    /// that already ended).
    func buzz() {
        buzz(deadline: Date().addingTimeInterval(8))
    }

    private func buzz(deadline: Date) {
        guard connection == .ready else {
            guard Date() < deadline else { return }
            ensureConnecting()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.buzz(deadline: deadline)
            }
            return
        }
        lastBuzzAcked = false
        for i in 0..<buzzRepeats {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * buzzRepeatInterval) { [weak self] in
                self?.sendOnePulse()
            }
        }
    }

    /// Each pulse is a confirmed write: the strap acks it, or we get an explicit error
    /// (no silent loss on a weak link). Confirmed writes are also flow-controlled by
    /// CoreBluetooth, so they are never dropped from a full queue like `.withoutResponse`.
    private func sendOnePulse() {
        guard let strap, let commandChar, connection == .ready else { return }
        seq &+= 1
        strap.writeValue(Data(WhoopFrame.buzz(seq: seq, loops: buzzLoops)), for: commandChar, type: .withResponse)
    }

    private func sendClientHello() {
        guard let strap, let commandChar else { return }
        connection = .handshaking
        expectingHelloAck = true
        strap.writeValue(Data(Whoop.clientHello), for: commandChar, type: .withResponse)
    }

    /// Tear down a stale/failed link; `didDisconnectPeripheral` then reconnects.
    private func bounceLink() {
        guard let strap else { return }
        connection = .connecting
        central.cancelPeripheralConnection(strap)
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
        lastSeenAt = Date()
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        commandChar = nil
        expectingHelloAck = false
        rssi = nil
        // Go straight to .connecting (not .disconnected) so the watchdog doesn't race
        // a second connect. iOS holds this pending and resumes when back in range.
        connection = .connecting
        central.connect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connection = .connecting
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
        guard characteristic.uuid == commandUUID else { return }
        if error != nil {
            expectingHelloAck = false
            bounceLink()            // the link is dead — reconnect and recover
            return
        }
        lastSeenAt = Date()
        if expectingHelloAck {
            expectingHelloAck = false
            connection = .ready     // CLIENT_HELLO acked → session open
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error != nil {
            bounceLink()
            return
        }
        lastSeenAt = Date()
        rssi = RSSI.intValue
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        lastSeenAt = Date()
        guard let value = characteristic.value else { return }
        if WhoopFrame.responseCommand([UInt8](value)) == Whoop.hapticCommand {
            lastBuzzAcked = true
        }
    }
}
