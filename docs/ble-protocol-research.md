# Protocollo BLE WHOOP 5.0 / MG — ricerca e grounding

> Questo documento traccia la fonte di **ogni** valore non inventabile usato nel codice
> (UUID, opcode, byte dei comandi, CRC). Niente qui è assunto: tutto è verificato nel
> codice di reverse-engineering citato o provato dai test in `WhoopProtocol`.

## Fonti

| Repo | Stack | Licenza | Modelli | Affidabilità |
|------|-------|---------|---------|--------------|
| [NoopApp/noop](https://github.com/NoopApp/noop) | Swift + Kotlin + Python | PolyForm Noncommercial 1.0.0 | 4.0 **e 5.0/MG** | Altissima — unica fonte con haptic 5.0/MG verificato su hardware reale |
| [bWanShiTong/reverse-engineering-whoop](https://github.com/bWanShiTong/reverse-engineering-whoop) | Python + TS | nessuna | 4.0 | Alta |
| [madhursatija/whoof](https://github.com/madhursatija/whoof) | JS / Web Bluetooth | MIT | 4.0 | Media |

**Nota licenza.** Il codice di `noop` è PolyForm Noncommercial: non riusabile in prodotti
commerciali. WhoopBuzz è un'app **personale non commerciale**, e in ogni caso il codice Swift
qui è **scritto da zero** portando i *fatti di protocollo* (UUID, opcode, layout dei byte) —
fatti di interoperabilità, non codice copiato. Il sorgente di riferimento letto è
[`tools/linux-capture/whoop_frame.py`](https://raw.githubusercontent.com/NoopApp/noop/main/tools/linux-capture/whoop_frame.py).

## 1. GATT — Service e Characteristic (WHOOP 5.0 / MG "puffin")

| Ruolo | UUID |
|-------|------|
| Service | `fd4b0001-cce1-4033-93ce-002d5875f58a` |
| Command WRITE | `fd4b0002-cce1-4033-93ce-002d5875f58a` |
| Notify | `fd4b0003 / 0004 / 0005 / 0007 -cce1-4033-93ce-002d5875f58a` |

Fonte: `DeviceFamily.swift`, `whoop_frame.py` (`FAMILIES["whoop5"]`). Codificati in
`WhoopProtocol/Sources/WhoopProtocol/WhoopConstants.swift`.

## 2. Frame "puffin"

```
[0xAA][format=0x01][declLength u16 LE][header u16][crc16 u16 LE][type][seq][cmd][payload…][crc32 u32 LE]
```
- `declLength` = lunghezza inner record + 4; inner record a offset 8; totale = `declLength + 8`.
- **CRC16-Modbus** (poly `0xA001`, init `0xFFFF`, reflected) sui **primi 6 byte** del frame.
- **CRC32 zlib** (poly `0xEDB88320`, init/xor `0xFFFFFFFF`, reflected) sull'**inner record**.
- **pad4**: l'inner record (type+seq+cmd+payload) va right-padded a zero fino a multiplo di 4 byte,
  altrimenti la strap rifiuta il frame (noop issue #48).

Implementato in `WhoopFrame.swift`. **Prova di correttezza**: il `CLIENT_HELLO` statico è esso stesso
un frame puffin valido; il test `testClientHelloIsReproducedFromBuilder` ricostruisce quei 16 byte
dal builder → se passa, header + CRC16 + inner + CRC32 sono corretti al byte.

## 3. CLIENT_HELLO (handshake)

16 byte statici scritti (confirmed write) su `fd4b0002` subito dopo la discovery, per aprire la
sessione cifrata; senza, le write di comando si bloccano.

```
AA 01 08 00 00 01 E6 71 23 01 91 01 36 3E 5C 8D
```
Fonte: `DeviceFamily.whoop5ClientHello`, `PROTOCOL.md §2.2/§5`.

## 4. Comando HAPTIC (vibrazione)

- Opcode: `0x13` = `RUN_HAPTIC_PATTERN_MAVERICK`. **NON** `79` (la strap 5/MG rifiuta 79 con
  `COMMAND_RESPONSE result=0x03`).
- Body "notify" (12 byte): `[0x01, 47, 152, 0, 0, 0, 0, 0, 0, 0, 0, 0]` — il preset di notifica gentile,
  identico byte-per-byte a quello dell'app ufficiale.
- Con pad4 → inner 16 byte → frame totale 28 byte (`testBuzzFrameStructure`).

Fonte: `whoop_frame.py` (`MAVERICK_HAPTIC_CMD = 0x13`, `MAVERICK_HAPTIC_NOTIFY`, `build_whoop5_buzz`).
La strap conferma con `COMMAND_RESPONSE` (type 36) che riecheggia l'opcode `0x13` — rilevato da
`WhoopFrame.responseCommand`.

## 5. Scanning

Scansionare **per service UUID** `fd4b0001-…` (più affidabile del nome su iOS, che spesso non espone
il local name in background). La strap si annuncia con nome che inizia per `WHOOP`, ma **non si annuncia
mentre è in carica** (va svegliata con un tap). Fonte: `BLE_REVERSE_ENGINEERING.md`, `whoof` README.

## 6. Vincoli operativi (verificati nelle fonti)

- **Keep-alive richiesto**: la strap lascia morire un link inattivo. Il codice di riferimento
  `Strand/BLE/BLEManager.swift` di NoopApp tiene un **keep-alive a 30s** (`keepAliveIntervalSeconds = 30`,
  comando `LINK_VALID` code 1) e **rimbalza il link** se non riceve dati per >120s
  (`cancelPeripheralConnection`). → WhoopBuzz genera traffico periodico con un heartbeat `readRSSI()`
  ogni 8s e forza la riconnessione se non vede segni di vita per >30s. Fonte:
  [NoopApp/noop BLEManager.swift / PROTOCOL.md](https://github.com/NoopApp/noop).
- **Scritture affidabili**: l'haptic va inviato come **confirmed write** (`.withResponse`): consegna
  garantita o errore esplicito. Le `.withoutResponse` su segnale debole vengono **scartate in silenzio**
  quando il buffer BLE è pieno (causa del "funziona solo a corto raggio"). Fonte:
  [Apple — canSendWriteWithoutResponse](https://developer.apple.com/documentation/corebluetooth/cbperipheral/cansendwritewithoutresponse),
  [Punch Through — Core Bluetooth guide](https://punchthrough.com/core-bluetooth-guide/).
- **Un solo central per volta**: se l'app WHOOP ufficiale è connessa, "ruba" la strap (single bond).
  WhoopBuzz e l'app ufficiale non possono tenere la connessione contemporaneamente. Fonte: NoopApp README.
- **Range fisico**: il corpo/polso attenua il 2.4 GHz e il TX power di un wearable è basso → range
  effettivo ridotto. Il TX power della strap e i connection parameter **non sono modificabili dall'app**;
  lato central si può solo massimizzare l'uptime del link e riconnettere in modo aggressivo.
- Il protocollo è **reverse-engineered**: un aggiornamento firmware WHOOP può romperlo.
- WHOOP 4.0 usa service e opcode diversi (`61080001-…`, opcode `79`) — **fuori scope** per questa app.
