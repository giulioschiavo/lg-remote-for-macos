# Changelog

## 1.0.3 — 27 ottobre 2026 · build 25

Small bugfix.

## 1.0.2 — 27 ottobre 2026 · build 24

WSS con certificato approvato e WS di riserva limitato; cinque pacchetti Wake-on-LAN; stato TV aggiornato con eventi e ping; impostazioni riorganizzate e screenshot IT/EN aggiornati. Vedi [note della release](RELEASE-NOTES-1.0.2.md). Accensione immediata e riconnessione verificate dall’utente; standby prolungato ancora da verificare.

## 1.0.1 — Setup improvements / Migliorie alla configurazione (24 October 2026, build 19)

### Italiano

- Ricerca TV via SSDP: l’utente vede le TV trovate e sceglie quale collegare, dopo aver approvato la richiesta sul televisore.
- Inserimento manuale dell’indirizzo sempre disponibile, con disclosure a tutta riga.
- Identità stabile USN per seguire la TV quando cambia indirizzo DHCP; dopo un primo collegamento con **Cerca TV**, il primo errore di connessione può tentare una sola riscoperta.
- Lettura di `wifiInfo`/`wiredInfo` da `getinfo`: gli stati sconosciuti restano candidati da verificare manualmente; il salvataggio automatico avviene solo con un unico candidato attivo confermato e campo MAC vuoto.
- Fallback ARP locale con conferma manuale.
- Calcolo automatico del broadcast della sottorete quando si sceglie una TV trovata.
- Impostazioni organizzate in tre schede: TV, Accensione e App.
- Una nuova associazione conserva la pairing key precedente finché la TV non accetta la registrazione; Rimuovi collegamento richiede conferma e rimuove associazione e identità salvate.
- Nessun servizio in background o di login e nessuna scansione TV periodica. Il controllo aggiornamenti GitHub resta facoltativo, con intervallo di 24 ore mentre l’app è aperta.

### English

- SSDP TV discovery: the user reviews found TVs and chooses which one to connect after approving the request on the TV.
- Manual address entry remains available through a full-row disclosure.
- Stable USN identity follows a TV across DHCP address changes; after one initial **Find TVs** connection, the first connection failure may attempt one rediscovery.
- `getinfo` reads `wifiInfo`/`wiredInfo`: unknown states remain candidates for manual verification; automatic saving occurs only for one confirmed active candidate when the MAC field is empty.
- Local ARP fallback requires manual confirmation.
- The subnet broadcast address is filled automatically when selecting a discovered TV.
- Settings are organized into three tabs: TV, Power On and App.
- Re-pairing preserves the previous pairing key until the TV accepts registration; Remove Connection is confirmed and clears saved pairing and identity.
- No background or login service and no periodic TV scans. The GitHub update check remains opt-in, with a 24-hour interval while the app is running.

This is a setup improvement release. It does not claim an overnight Wake-on-LAN fix or universal TV compatibility.

## 1.0 — Initial launch / Lancio iniziale

- Default-off opt-in check for new GitHub Releases at startup and every 24 hours while the app is running.
- Manual update check remains available at any time.
- Available-release banner inside the app and a native notification when macOS notification permission is available.
- The release link opens only when the user chooses it; there is no automatic download or installation.
- Network requests go only to GitHub when the opt-in check is enabled or a manual check is started; no analytics or tracking requests are added.
- Version 1.0 is the launched build 14. The earlier 1.6 numbering was prelaunch and requires one manual replacement for users who installed it.

The v1.0 release is distributed as an arm64 ZIP. The update check never downloads or installs automatically.

## 1.6 — Prelaunch preparation / Preparazione prima del lancio

- English and Italian interface, including accessibility labels and app display name.
- Optional Magic Remote network pointer; buttons remain available when disabled.
- Four speed levels; the new 2× preserves the previous 4× movement multiplier.
- Native menu bar panel, volume, tuner channels, inputs, navigation and power commands.
- Local pairing in Keychain and configurable Wake-on-LAN.
- Relative touchpad restored after experimental centering/absolute mapping was removed.
- README in both languages, MIT license and compatibility reporting guidance.

This was a prelaunch build. It had no automatic update check; notarization, secure WebSocket transport and universal TV compatibility were not claimed.
