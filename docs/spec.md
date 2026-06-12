# WhoopBuzz — Spec tecnica

## Obiettivo
Far vibrare un braccialetto WHOOP 5.0 / MG all'arrivo di una chiamata sull'iPhone, per sostituire
l'Apple Watch nel solo ruolo di "avviso chiamate".

## Scope
**In scope:** vibrazione del braccialetto su chiamata in arrivo (nativa + VoIP via CallKit: WhatsApp,
FaceTime, Telegram). Pulsante "prova vibrazione". Indicatore di stato connessione.

**Fuori scope:** notifiche di messaggi testuali (WhatsApp/SMS) — impossibili da intercettare per
un'app iOS di terze parti (iOS non espone le notifiche altrui, a differenza di Android). Lettura dati
fisiologici dal braccialetto. Supporto WHOOP 4.0 (protocollo diverso).

## Architettura

```
┌─────────────┐   chiamata in arrivo   ┌─────────────┐   buzz frame (BLE)   ┌──────────────┐
│ CallMonitor │ ─────────────────────▶ │  AppState   │ ───────────────────▶ │ WhoopBLEMgr  │ ─▶ WHOOP
│ CXCallObserver                       │ (debounce)  │                      │ CoreBluetooth│
└─────────────┘                        └─────────────┘                      └──────────────┘
                                                                                    │
                                                                            WhoopProtocol (puro)
                                                                            frame + CRC + costanti
```

- **`WhoopProtocol`** (Swift package, puro Foundation): costruzione frame puffin, CRC16-Modbus + CRC32,
  costanti BLE. Testato in isolamento — è la parte dove la correttezza è non-negoziabile e non dipende
  dall'hardware. Vedi `docs/ble-protocol-research.md`.
- **`WhoopBLEManager`** (CoreBluetooth): scan per service UUID → connect → discover → `CLIENT_HELLO`
  (confirmed write) → enable notify → `ready`. Riconnessione automatica su disconnect. `CBCentralManager`
  con restore identifier per la sopravvivenza in background.
- **`CallMonitor`** (CallKit): `CXCallObserver` → callback su chiamata in arrivo ringing.
- **`AppState`**: collega chiamata → buzz, con debounce 2s. Espone stato alla UI.
- **`ContentView`** (SwiftUI): stato connessione, toggle abilitazione, pulsante di prova.

## Vincoli tecnici
- iOS 16+. Background mode `bluetooth-central`. `NSBluetoothAlwaysUsageDescription` obbligatoria.
- Il braccialetto accetta un solo central per volta (conflitto con app WHOOP ufficiale).
- Protocollo reverse-engineered: fragile rispetto agli aggiornamenti firmware WHOOP.

## Rischi (i 3 principali)
1. **Affidabilità background/CallKit** — iOS potrebbe non risvegliare l'app o `CXCallObserver` potrebbe
   non scattare a telefono bloccato. È l'incognita numero uno, da validare su device.
2. **Stabilità connessione BLE** — mantenere il link sempre vivo consuma batteria e può cadere; la
   riconnessione introduce latenza prima che il buzz sia possibile.
3. **Rottura da firmware** — un update WHOOP può cambiare UUID/opcode e azzerare il funzionamento.

## Criteri di accettazione
- [x] `swift test` su `WhoopProtocol` verde (incluso golden vector CLIENT_HELLO).
- [ ] L'app si compila e installa su iPhone fisico.
- [ ] Pulsante "prova" → il braccialetto vibra (prova in primo piano).
- [ ] Chiamata in arrivo con app in primo piano → vibrazione.
- [ ] Chiamata in arrivo con app in background / telefono bloccato → vibrazione (rischio #1).
- [ ] Chiamata WhatsApp in arrivo → vibrazione.
