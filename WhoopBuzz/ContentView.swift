import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Stato braccialetto") {
                    LabeledContent("Connessione") {
                        HStack(spacing: 8) {
                            Circle().fill(statusColor).frame(width: 10, height: 10)
                            Text(statusText)
                        }
                    }
                    if let name = app.ble.deviceName {
                        LabeledContent("Dispositivo", value: name)
                    }
                    if app.ble.connection == .scanning {
                        LabeledContent("Dispositivi BLE visti", value: "\(app.ble.scannedCount)")
                    }
                    if let rssi = app.ble.rssi, app.ble.connection == .ready {
                        LabeledContent("Segnale", value: "\(signalLabel(rssi)) (\(rssi) dBm)")
                    }
                }

                Section("Notifiche chiamate") {
                    Toggle("Vibra all'arrivo di una chiamata", isOn: $app.buzzOnCallEnabled)
                    if let last = app.lastCallBuzz {
                        LabeledContent("Ultima vibrazione", value: last.formatted(date: .omitted, time: .standard))
                    }
                }

                Section("Prova") {
                    Button("Fai vibrare ora") { app.testBuzz() }
                        .disabled(app.ble.connection != .ready)
                    if app.ble.lastBuzzAcked {
                        Label("Vibrazione confermata dal braccialetto", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }

                if app.ble.connection == .disconnected || app.ble.connection == .bluetoothOff {
                    Section {
                        Button("Cerca il braccialetto") { app.startBluetooth() }
                    }
                }
            }
            .navigationTitle("WhoopBuzz")
        }
        .onAppear { app.startBluetooth() }
    }

    private var statusText: String {
        switch app.ble.connection {
        case .bluetoothOff: return "Bluetooth spento"
        case .unauthorized: return "Permesso Bluetooth negato"
        case .scanning: return "Ricerca in corso…"
        case .connecting: return "Connessione…"
        case .handshaking: return "Handshake…"
        case .ready: return "Pronto"
        case .disconnected: return "Disconnesso"
        }
    }

    private func signalLabel(_ rssi: Int) -> String {
        switch rssi {
        case (-65)...: return "Ottimo"
        case (-80)..<(-65): return "Buono"
        default: return "Debole"
        }
    }

    private var statusColor: Color {
        switch app.ble.connection {
        case .ready: return .green
        case .scanning, .connecting, .handshaking: return .orange
        default: return .red
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
