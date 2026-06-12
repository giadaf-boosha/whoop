# WhoopBuzz — Piano di implementazione

## Sprint 0 — Protocollo verificato ✅ FATTO
- [x] Ricerca e grounding del protocollo BLE da fonti reverse-engineered (`docs/ble-protocol-research.md`)
- [x] Package `WhoopProtocol`: CRC16-Modbus, CRC32 zlib, frame builder puffin, pad4, costanti
- [x] Test: check-value CRC catalogati + **golden vector CLIENT_HELLO** + struttura buzz + validazione
- [x] `swift test` → 9/9 verde

**DoD:** il frame builder ricostruisce il CLIENT_HELLO ufficiale byte-per-byte. ✅

## Sprint 1 — App iOS (BLE + chiamate + UI) ✅ CODICE FATTO
- [x] `WhoopBLEManager`: scan/connect/handshake/notify/buzz + riconnessione + state restoration
- [x] `CallMonitor`: `CXCallObserver` → chiamata in arrivo
- [x] `AppState`: wiring chiamata→buzz con debounce
- [x] `ContentView`: stato + toggle + pulsante prova
- [x] `Info.plist`: permesso Bluetooth + background mode
- [x] Progetto Xcode (package locale, scheme condiviso) — `plutil -lint` OK

**DoD:** progetto strutturalmente valido. Build completa su device = Sprint 2 (richiede hardware).

## Sprint 2 — Validazione su hardware ✅ FATTO (su iPhone 17 Pro Max + WHOOP, 2026-06-12)
- [x] Toolchain Xcode riparata, build + install + launch via CLI (`xcodebuild` + `devicectl`)
- [x] Team di firma a pagamento (`ZJL5DVGA79`) — niente scadenza a 7 giorni
- [x] Pulsante "Fai vibrare ora" → vibra
- [x] Chiamata in arrivo (foreground) → vibra
- [x] **Chiamata a telefono bloccato → vibra** (il rischio #1 è risolto)
- [x] **Chiamate multiple consecutive da bloccato → vibrano tutte** (keep-alive sopravvive all'interruzione)

**Fix chiave emersi dal campo:**
- Scan per **nome** "WHOOP" + `retrieveConnectedPeripherals` (lo scan per service UUID non trovava il braccialetto).
- Buzz tramite **loops interni** del comando haptic (ultimo byte del body = ripetizioni) invece di N scritture
  temporizzate: forte e affidabile anche durante il caos di una chiamata in arrivo.
- Keep-alive con **`AVAudioPlayer`** (non `AVAudioEngine`) + ripresa su `interruption .ended`: sopravvive
  alle chiamate; senza, funzionava solo la prima chiamata.

## Sprint 3 — Stabilità "sempre attiva" ✅ FATTO
- [x] **Watchdog di riconnessione** (ogni 8s): recupera da qualsiasi drop (fuori raggio, carica, app
      ufficiale che ruba il braccialetto) senza intervento utente.
- [x] **State restoration** (`CBCentralManagerOptionRestoreIdentifierKey`): iOS rilancia l'app in
      background dopo un evento BLE anche se l'aveva terminata per memoria.
- [x] Buzz forte/lungo: loops **6** (valore accettato dal firmware — 15 veniva rifiutato → nessuna
      vibrazione) × **7 ripetizioni** ~1.1s → buzz sostenuto di ~8 secondi.
- [x] **App icon**: smartwatch + onde radio su gradiente, generata via `tools/make_icon.swift`
      (CoreGraphics, 1024×1024 opaca senza alpha), asset catalog + `ASSETCATALOG_COMPILER_APPICON_NAME`.

**Limiti strutturali iOS (non aggirabili, documentati in README):** force-quit manuale e riavvio del
telefono richiedono di riaprire l'app una volta; il profilo di firma scade circa ogni 12 mesi.
