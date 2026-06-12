import Combine
import Foundation

/// Wires incoming calls to the strap buzz and exposes state to the UI.
final class AppState: ObservableObject {
    let ble = WhoopBLEManager()
    private let calls = CallMonitor()
    private let keepAlive = KeepAlive()

    @Published var buzzOnCallEnabled = true {
        didSet { updateKeepAlive() }
    }

    /// Timestamp of the last buzz we fired, for the UI log.
    @Published private(set) var lastCallBuzz: Date?

    private var cancellables = Set<AnyCancellable>()
    private var lastFired: Date = .distantPast

    init() {
        calls.onIncomingCall = { [weak self] in self?.handleIncomingCall() }
        // Re-publish the BLE manager's changes so views observing AppState refresh.
        ble.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        updateKeepAlive()
    }

    private func updateKeepAlive() {
        if buzzOnCallEnabled {
            keepAlive.start()
        } else {
            keepAlive.stop()
        }
    }

    func startBluetooth() {
        ble.start()
    }

    func testBuzz() {
        ble.buzz()
    }

    private func handleIncomingCall() {
        guard buzzOnCallEnabled else { return }
        // Debounce: CallKit can report a ringing call more than once.
        guard Date().timeIntervalSince(lastFired) > 2 else { return }
        lastFired = Date()
        lastCallBuzz = Date()
        ble.buzz()
    }
}
