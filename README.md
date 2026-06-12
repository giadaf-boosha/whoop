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
WhoopBuzz/            App iOS (SwiftUI): BLE manager, osservatore chiamate, keep-alive, UI, app icon.
WhoopBuzz.xcodeproj/  Progetto Xcode (dipende dal package locale WhoopProtocol).
tools/make_icon.swift Generatore dell'app icon (CoreGraphics, 1024×1024 senza alpha).
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

## Stabilità — come resta "sempre attiva"

Cosa garantisce il funzionamento continuo (già in codice):
- **Keep-alive audio**: una sessione audio silenziosa (`.mixWithOthers`, non interrompe la musica)
  impedisce a iOS di sospendere l'app a schermo bloccato, così `CXCallObserver` scatta sempre e la
  scrittura BLE parte. Si riattiva da sola dopo ogni chiamata.
- **Heartbeat BLE** (`readRSSI` ogni 8s): tiene il link sveglio (il braccialetto scollega i link
  inattivi) e rileva un link "zombie" (nessun segno di vita per >30s → riconnessione forzata).
- **Buzz affidabile** (`.withResponse`): ogni comando è confermato dal braccialetto o dà errore (→
  riconnessione). Le scritture non confermate venivano perse in silenzio a segnale debole, dando
  l'impressione che funzionasse solo a corto raggio.
- **Retry del buzz**: se la chiamata arriva mentre il link si sta riconnettendo, l'app ritenta per
  qualche secondo finché torna pronta.
- **State restoration**: se iOS termina l'app in background per memoria, la rilancia da solo al primo
  evento Bluetooth del braccialetto.
- **Indicatore di segnale** in app (RSSI): per capire se sei in un punto a segnale debole.

Cosa invece richiede un gesto tuo (limiti strutturali di iOS, non aggirabili):
- **Non fare force-quit** dell'app (non scartarla dall'app switcher): iOS non rilancia un'app chiusa
  manualmente. Se lo fai, riaprila una volta.
- **Dopo un riavvio del telefono**: riapri l'app una volta (nessuna app sideloaded può auto-avviarsi al boot).
- **Firma**: con account a pagamento il profilo dura ~12 mesi; dopo, l'app va re-installata (un comando).

## Altri limiti noti

- **Conflitto con l'app WHOOP ufficiale**: il braccialetto accetta **un solo dispositivo per volta**.
  Quando apri l'app WHOOP ufficiale per sincronizzare, "ruba" il braccialetto e in quel momento le
  chiamate non fanno vibrare; appena la chiudi, WhoopBuzz si riconnette da sola (watchdog).
- **In carica**: il braccialetto sotto carica non si fa trovare → niente buzz mentre carica.
- **Solo chiamate**: niente notifiche di messaggi WhatsApp testuali — su iPhone è impossibile per
  un'app di terze parti leggere le notifiche altrui.
- **Batteria**: BLE persistente + audio keep-alive consumano batteria extra (telefono e braccialetto).
  Quantità da osservare nell'uso reale; ottimizzabile se eccessiva.
