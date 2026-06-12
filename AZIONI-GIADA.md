# Azioni per Giada — dal codice al braccialetto che vibra

Passi in ordine. I primi due funzionano subito, senza braccialetto.

## 1. Verifica il protocollo (subito, senza hardware)
```sh
cd ~/code/whoop/WhoopProtocol
swift test
```
Atteso: `Executed 9 tests, with 0 failures`. Il test `testClientHelloIsReproducedFromBuilder` prova
che il frame builder è corretto al byte.

## 2. Ripara il toolchain Xcode (una volta)
Al momento `xcodebuild` non carica il plugin del simulatore. Sistemalo così:
```sh
sudo xcodebuild -runFirstLaunch
```
Se chiede di installare componenti aggiuntivi, accetta. In alternativa apri Xcode dall'icona e lascia
che completi l'installazione al primo avvio. Poi verifica:
```sh
cd ~/code/whoop
xcodebuild -list -project WhoopBuzz.xcodeproj   # deve elencare lo scheme "WhoopBuzz"
```

## 3. Apri il progetto e firma
```sh
open ~/code/whoop/WhoopBuzz.xcodeproj
```
In Xcode:
1. Seleziona il target **WhoopBuzz** → tab **Signing & Capabilities**.
2. Spunta **Automatically manage signing** e scegli il tuo **Team** (il tuo Apple ID personale va bene).
3. Se serve, cambia il **Bundle Identifier** (es. `com.tuonome.whoopbuzz`) per renderlo unico.

## 4. Installa sull'iPhone
1. Collega l'iPhone, sbloccalo, autorizza il computer.
2. In alto in Xcode scegli il tuo iPhone come destinazione (non un simulatore).
3. Premi ▶︎ (Run). Alla prima installazione: su iPhone vai in
   **Impostazioni → Generali → VPN e gestione dispositivo** e fidati del tuo certificato sviluppatore.
4. Concedi il permesso **Bluetooth** quando l'app lo chiede.

## 5. Prova (in ordine di rischio crescente)
1. Togli il braccialetto dal caricatore, dagli un tap. Chiudi l'app WHOOP ufficiale.
2. Nell'app, attendi stato **"Pronto"** (pallino verde).
3. Premi **"Fai vibrare ora"** → il braccialetto deve vibrare. Comparirà "Vibrazione confermata".
4. Fatti chiamare con **l'app in primo piano** → deve vibrare.
5. Fatti chiamare con **app in background / telefono bloccato** → deve vibrare. ⬅️ **il test decisivo**
6. Fatti chiamare su **WhatsApp** → deve vibrare.

## 6. Riferiscimi i risultati
Dimmi a quale punto del passo 5 funziona o si rompe. Se il punto 5.5 (background) non vibra, è il
problema noto numero uno: a quel punto valutiamo le contromisure dello Sprint 3
(`docs/implementation_plan.md`), per cui mi servono i tuoi dati reali prima di scrivere altro codice.
