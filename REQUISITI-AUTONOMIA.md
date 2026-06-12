# Requisiti di autonomia (per l'agente)

Cosa serve perché un agente possa lavorare su questo repo senza intervento umano, e cosa **non** può
fare da solo.

## Disponibile e usabile dall'agente
- `swift` (6.3+) → build e test del package `WhoopProtocol`. **È la verifica primaria del progetto.**
- `git` + `gh` autenticato (`giadaf-boosha`) → branch, commit, PR.
- `plutil` → lint di `Info.plist` e `project.pbxproj`.

## NON disponibile all'agente (richiede l'umano)
- **iPhone fisico + braccialetto WHOOP 5/MG** → ogni verifica BLE/CallKit reale (lo Sprint 2 intero).
- **Toolchain Xcode funzionante** → al momento `xcodebuild` non carica il plugin simulatore; va riparato
  con `xcodebuild -runFirstLaunch` (sulla macchina dell'utente, non in sandbox).
- **Firma del codice** → richiede l'Apple ID/Team dell'utente.

## Confine di verifica
- ✅ L'agente PUÒ provare la correttezza del **protocollo** (`swift test`, golden vector).
- ✅ L'agente PUÒ validare la struttura del progetto iOS (`plutil`).
- ❌ L'agente NON PUÒ compilare l'app iOS completa qui (toolchain rotto + niente signing) né provare la
  vibrazione (niente hardware). Questi passi sono delegati a `AZIONI-GIADA.md`.

## Regola di grounding specifica del progetto
Nessun valore BLE (UUID, opcode, byte di comando) va mai inventato o modificato senza una fonte in
`docs/ble-protocol-research.md`. Se un valore cambia, va prima aggiornato lì con la fonte, poi nel codice,
poi nei test.
