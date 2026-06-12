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

## Sprint 2 — Validazione su hardware ⏳ RICHIEDE GIADA + DISPOSITIVI
Bloccato da: (a) Xcode toolchain da riparare (`xcodebuild -runFirstLaunch`), (b) iPhone + braccialetto.
- [ ] Riparare toolchain Xcode, aprire il progetto, impostare Team di firma, build su iPhone
- [ ] Prova in primo piano: pulsante "Fai vibrare ora" → il braccialetto vibra + ack confermato
- [ ] Prova chiamata nativa in arrivo (foreground) → vibrazione
- [ ] Prova chiamata in background / telefono bloccato → vibrazione **(rischio #1 — validare qui)**
- [ ] Prova chiamata WhatsApp → vibrazione
- [ ] Misura impatto batteria della connessione BLE persistente nelle 24h

**DoD:** vibrazione affidabile su chiamata in arrivo a telefono bloccato.

## Sprint 3 — Robustezza (solo se Sprint 2 mostra problemi)
Possibili interventi *se* il background si rivela inaffidabile:
- [ ] Pattern di buzz ripetuto finché la chiamata squilla
- [ ] Gestione esplicita del conflitto con l'app WHOOP ufficiale (avviso in UI)
- [ ] Strategia di re-firma per la scadenza 7 giorni (se firma gratuita)

Non implementare nulla di Sprint 3 prima dei dati di Sprint 2 (YAGNI).
