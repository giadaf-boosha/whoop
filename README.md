# WhoopBuzz

App iOS personale che fa **vibrare il braccialetto WHOOP 5.0 / MG quando ricevi una chiamata**
(chiamate native del telefono **e** chiamate WhatsApp/FaceTime/Telegram, perché passano tutte da CallKit).

Nasce per non dover più indossare l'Apple Watch solo per accorgersi delle chiamate.

> ⚠️ Non ufficiale, non supportato da WHOOP. Usa il protocollo BLE reverse-engineered del braccialetto
> (vedi [`docs/ble-protocol-research.md`](docs/ble-protocol-research.md)). Un aggiornamento firmware
> di WHOOP può smettere di funzionare da un giorno all'altro.

## Come funziona

1. L'app resta connessa via Bluetooth al braccialetto (scan per service UUID → connect → `CLIENT_HELLO`).
2. Un osservatore CallKit (`CXCallObserver`) rileva le chiamate in arrivo.
3. All'arrivo di una chiamata, l'app invia al braccialetto il comando haptic "notify" (opcode `0x13`),
   identico a quello dell'app WHOOP ufficiale → il braccialetto vibra.

## Struttura

```
WhoopProtocol/        Package Swift puro: framing BLE + CRC + costanti. ZERO dipendenze di piattaforma.
                      È il cuore verificato del progetto — `swift test` passa 9/9, incluso il golden
                      vector che ricostruisce il CLIENT_HELLO ufficiale byte-per-byte.
WhoopBuzz/            App iOS (SwiftUI): BLE manager, osservatore chiamate, UI.
WhoopBuzz.xcodeproj/  Progetto Xcode (dipende dal package locale WhoopProtocol).
docs/                 Spec, piano, e ricerca sul protocollo con tutte le fonti.
```

## Stato

| Componente | Stato |
|------------|-------|
| Protocollo BLE (`WhoopProtocol`) | ✅ Implementato e **testato** (`swift test` → 9/9, golden vector incluso) |
| App iOS (BLE + CallKit + UI) | ✅ Implementata — **da compilare e provare su iPhone fisico** |
| Verifica su hardware reale | ⏳ Richiede iPhone + braccialetto WHOOP 5/MG (vedi sotto) |

## Provarla (per Giada)

Vedi **[`PRECONDIZIONI-UTENTE.md`](PRECONDIZIONI-UTENTE.md)** e **[`AZIONI-GIADA.md`](AZIONI-GIADA.md)** per
i passi esatti. In sintesi:

```sh
# 1. test del protocollo (funziona ovunque, senza hardware)
cd WhoopProtocol && swift test

# 2. l'app: aprire in Xcode, impostare il proprio Team di firma, e installare su iPhone
open WhoopBuzz.xcodeproj
```

## Limiti noti (onestà prima di tutto)

- **Affidabilità in background**: iOS può sospendere l'app. La connessione BLE persistente + la
  background mode `bluetooth-central` la tengono viva, ma **questo è il punto da validare su device**:
  va verificato che `CXCallObserver` scateni la vibrazione a telefono bloccato e app in background.
- **Conflitto con l'app WHOOP ufficiale**: il braccialetto accetta **un solo dispositivo per volta**.
  Mentre WhoopBuzz è connessa, l'app WHOOP ufficiale non può sincronizzare (e viceversa).
- **Solo chiamate**: niente notifiche di messaggi WhatsApp testuali — su iPhone è impossibile per
  un'app di terze parti leggere le notifiche altrui. Vedi la chat di progetto per il perché.
- **Firma gratuita**: senza un account Apple Developer a pagamento, l'app va re-installata ogni 7 giorni.
