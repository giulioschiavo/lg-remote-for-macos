# Passaggio progetto LG Remote per macOS

Aggiornato: 23 ottobre 2026.

## Riferimenti e versione

- Repository pubblico: https://github.com/giulioschiavo/lg-remote-for-macos
- Cartella di consegna: `publish/lg-remote-for-macos` nel workspace originale.
- Pacchetto approvato per la Release: `Downloads/LG-Remote-1.0-macOS-arm64.zip`.
- Versione 1.0, build 14; bundle `it.giulio.LGRemote`; Apple Silicon arm64, macOS 13+.
- SHA-256 ZIP: `13f0ee1708ef62c124eadb2460a241e86a41bbb4e90e29326acf836fd6bff038`.
- Launch status: version 1.0/build 14 is the current release. The earlier 1.6 numbering was prelaunch; users on 1.6 must replace it manually once with 1.0.

## Decisioni da preservare

- App personale gratuita, MIT, indipendente da LG; autore Giulio Schiavo, sviluppo assistito dall’AI.
- Test reali dichiarati solo su LG 55UM7450PLA; compatibilità universale non garantita.
- Accensione tramite Wake-on-LAN solo sulla rete locale, non via internet. Il pacchetto inviato non prova che la TV si sia accesa.
- Wi-Fi ed Ethernet hanno MAC distinti; usare quello della connessione attiva, non l’identificativo AirPlay.
- WebSocket attuale `ws://<TV>:3000`; `wss://` sulla 3001 non implementato.
- Chiavi nel Portachiavi, preferenze locali; nessun account cloud o analytics.
- Firma ad-hoc; nessuna firma Developer ID o notarizzazione.
- Version 1.0 adds a default-off opt-in GitHub Releases check at startup and every 24 hours while running; a manual check is always available.
- Update results appear in an in-app available banner and, when notification permission is available, a native notification. Opening the release link is manual; there is no automatic download or installation.
- Requests go only to GitHub when the opt-in or manual check is used. No analytics or tracking requests are added.
- Version 1.6 cannot check for updates and must be replaced manually with 1.0.
- Touchpad relativo, senza mappatura assoluta o ricentraggio; puntatore disattivabile.
- Documentazione italiana e inglese, anteprime con dati sintetici, icone chiara/scura.

## Verifiche del 23 ottobre 2026

- Prima delle modifiche: clone remoto al commit `537580e988779e2f2d1d95bd93e50da22aee4004`; nessuna Release pubblicata.
- Sorgenti, localizzazioni, plist, script e icone remoti identici ai file locali.
- ZIP integro; versione e architettura confermate; firma verificata; self-test superato in italiano e inglese.
- Screenshot italiano controllato visivamente. README aggiornati con MAC, abilitazione accensione e link al pacchetto Release.
- Pacchetto 1.0 ricostruito dai sorgenti aggiornati; il vecchio ZIP 1.6 resta conservato.
- La cartella publish originale aveva un repository Git senza commit e senza remoto; non usare uno stato staged come prova di pubblicazione.
- Nessun nuovo test su TV fisica eseguito durante questa ripresa.
- La documentazione è stata aggiornata per il lancio v1.0; il precedente v1.6 è conservato solo come riferimento archivistico prelaunch.

## Consegna e attività

- COMPLETATO: preparazione della Release `v1.0` con il pacchetto `Downloads/LG-Remote-1.0-macOS-arm64.zip`; la pubblicazione remota è gestita dal task principale.
- ARCHIVIO: la precedente Release `v1.6` e il relativo pacchetto restano riferimenti storici del prelaunch.
- Futuro: test su altri modelli, WSS e discovery, Developer ID/notarizzazione, eventuale Intel.
- Per ogni modifica futura leggere prima stato remoto e file correnti; preservare testo approvato e binario distribuito.

## Validazione 1.0

- Build arm64 completata; self-test IT/EN e test versioni/decodifica/link Release superati, inclusa risposta reale GitHub.
- Impostazioni reali renderizzate; area scorrevole per mantenere accessibili i controlli.
- Notifica nativa implementata; consegna tramite Centro Notifiche non ancora verificata con una nuova Release effettiva.
- Impostare esplicitamente v1.0 come Latest: v1.6 è una numerazione prelaunch storica. Le prossime Release devono essere marcate Latest.

## Esito finale lancio

- Release pubblica verificata: https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.0
- GitHub Latest/API confermati su v1.0; download pubblico identico al pacchetto locale.
- Sorgenti e documentazione pubblicati al commit c16ae4b3874cce0787e7e899c1d8f73f9f3bca36.
- Copia locale aggiornata e avviata: `/Applications/Telecomando LG.app`, versione1.0 build14, binario identico alla distribuzione.
- App precedente conservata in `publish/backup-local/Telecomando LG-pre-1.0.app`; preferenze e Portachiavi preservati.
- Controllo automatico disattivato per impostazione iniziale: attivarlo nelle impostazioni dell’app e autorizzare le notifiche macOS.
