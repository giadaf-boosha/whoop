# Precondizioni utente

Checklist di ciò che serve **a te (umano)** per portare WhoopBuzz dal codice al braccialetto che vibra.

## Hardware necessario
- [ ] iPhone fisico (iOS 16+). **Il simulatore non basta**: CoreBluetooth e CallKit non funzionano nel simulatore.
- [ ] Braccialetto WHOOP 5.0 o WHOOP MG (NON il 4.0 — protocollo diverso, fuori scope).
- [ ] Cavo o connessione per installare l'app da Xcode all'iPhone.

## Account e firma
- [ ] Un Apple ID per firmare l'app (basta quello gratuito; con quello l'app scade ogni 7 giorni e va re-installata).
- [ ] In Xcode: aver effettuato l'accesso con l'Apple ID (Settings → Accounts).

## Toolchain da sistemare
- [ ] **Xcode va riparato**: al momento sulla tua macchina il toolchain del simulatore è rotto
      (`xcodebuild` fallisce caricando `IDESimulatorFoundation`). Apri Xcode una volta e lascia che
      completi l'installazione dei componenti, oppure esegui `xcodebuild -runFirstLaunch`. Vedi
      `AZIONI-GIADA.md`.

## Condizioni d'uso del braccialetto
- [ ] **Chiudi/disconnetti l'app WHOOP ufficiale** mentre usi WhoopBuzz: il braccialetto accetta un solo
      dispositivo per volta.
- [ ] Il braccialetto **non si annuncia via Bluetooth mentre è in carica**: per il primo abbinamento,
      toglilo dal caricatore e dagli un tap per "svegliarlo".

## Aspettative oneste
- [ ] So che è un progetto **non ufficiale** basato su reverse-engineering e che un aggiornamento
      firmware WHOOP può romperlo.
- [ ] So che le **notifiche di messaggi WhatsApp testuali non sono possibili** su iPhone — solo le chiamate.
- [ ] So che l'affidabilità a **telefono bloccato** è il punto ancora da verificare sul campo.
