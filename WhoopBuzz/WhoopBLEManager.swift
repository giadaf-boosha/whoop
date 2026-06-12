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

    private var central: CBCentralManager!
    private var strap: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var seq: UInt8 = 0

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
    }

    /// Begin scanning if Bluetooth is ready and we are not already connected.
    func start() {
        guard central.state == .poweredOn else { return }
        guard strap == nil else { return }
        connection = .scanning
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    /// Send the notify-style haptic buzz. Safe to call when not ready (no-op).
    func buzz() {
        guard let strap, let commandChar, connection == .ready else { return }
        lastBuzzAcked = false
        seq &+= 1
        let frame = Data(WhoopFrame.buzz(seq: seq))
        strap.writeValue(frame, for: commandChar, type: .withoutResponse)
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
        central.stopScan()
        strap = peripheral
        deviceName = peripheral.name
        peripheral.delegate = self
        connection = .connecting
        central.connect(peripheral)
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
