# LG Remote 1.0.1

24 October 2026 · build 19 · Apple Silicon arm64

## Italiano

LG Remote 1.0.1 migliora la configurazione iniziale e la gestione delle TV che cambiano indirizzo sulla rete locale.

- **Cerca TV** usa SSDP e mostra le TV rilevate. Scegli la TV e approva la richiesta di associazione sul televisore.
- L’inserimento manuale del nome o dell’indirizzo IPv4 resta disponibile nella sezione apribile a tutta riga.
- L’identità stabile ricavata dall’USN consente di riconoscere la TV dopo un cambio DHCP. Serve una prima connessione tramite **Cerca TV** per registrare l’identità; se il primo collegamento successivo fallisce, l’app tenta una sola riscoperta.
- La lettura `getinfo` usa `wifiInfo` e `wiredInfo`. Se lo stato è sconosciuto, l’app mostra il candidato e richiede conferma manuale. Il salvataggio automatico è limitato a un unico candidato attivo confermato quando il campo MAC è vuoto.
- Se la TV non restituisce un MAC utilizzabile, il fallback ARP è locale e richiede sempre conferma manuale.
- Quando selezioni una TV trovata, l’app prova a compilare automaticamente il broadcast della sottorete.
- Le impostazioni sono divise in tre schede: **TV**, **Accensione** e **App**.
- **Ripeti associazione** mantiene la chiave precedente fino alla registrazione accettata dalla TV. **Rimuovi associazione** richiede conferma e cancella associazione, identità, MAC e broadcast salvati.

Non vengono aggiunti servizi in background, servizi di login o scansioni TV periodiche. Il controllo aggiornamenti GitHub resta disattivato per impostazione predefinita, può essere avviato manualmente e, se attivato, controlla all’avvio e ogni 24 ore mentre l’app è aperta. Non installa né scarica aggiornamenti automaticamente.

Questa versione migliora la configurazione. Non dichiara una correzione per l’accensione dopo una notte in standby e non dichiara compatibilità universale.

Modello testato: LG 55UM7450PLA. Requisiti: macOS 13 o successivo su Apple Silicon. La compilazione distribuita ha firma ad-hoc e non è firmata Developer ID né notarizzata.

## English

LG Remote 1.0.1 improves initial setup and handling of TVs whose local DHCP address changes.

- **Find TVs** uses SSDP and lists discovered TVs. Choose a TV and approve the pairing request on the television.
- Manual hostname or IPv4 entry remains available in a full-row expandable section.
- The stable USN identity lets the app recognize a TV after a DHCP change. A first connection through **Find TVs** is required to seed the identity; if the next initial connection fails, the app makes one rediscovery attempt.
- `getinfo` reads `wifiInfo` and `wiredInfo`. Unknown state leaves a candidate for manual confirmation. Automatic saving is limited to one confirmed active candidate when the MAC field is empty.
- If the TV does not return a usable MAC, the local ARP fallback always requires manual confirmation.
- Selecting a discovered TV triggers automatic subnet-broadcast detection when an unambiguous result is available.
- Settings are divided into three tabs: **TV**, **Power On** and **App**.
- **Pair Again** keeps the previous pairing key until the TV accepts registration. **Remove Pairing** requires confirmation and clears saved pairing, identity, MAC and broadcast values.

The app adds no background service, login item or periodic TV scan. The GitHub update check remains off by default, can be started manually and, when enabled, runs at startup and every 24 hours while the app is open. It never downloads or installs updates automatically.

This release improves setup. It does not claim an overnight standby Wake-on-LAN fix or universal TV compatibility.

Tested model: LG 55UM7450PLA. Requirements: macOS 13 or later on Apple Silicon. The distributed build is ad-hoc signed and is not Developer ID signed or notarized.
