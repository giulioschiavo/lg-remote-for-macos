# Passaggio progetto LG Remote per macOS

Aggiornato: 24 ottobre 2026. Release preparata: **1.0.1, build 19**, Apple Silicon arm64, macOS 13+.

## Distribuzione

Repository: https://github.com/giulioschiavo/lg-remote-for-macos
Release prevista: https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.0.1
Pacchetto: `Downloads/LG-Remote-1.0.1-macOS-arm64.zip`.
SHA-256: `689a051b67e033b25be57fc5565deaaee7fa873bccef8b0fdaca4671bc39cd66`.
La pubblicazione va verificata separatamente dalla preparazione locale.

## Decisioni

- Progetto personale MIT di Giulio Schiavo, indipendente da LG; sviluppo assistito dall’AI.
- Test reali dichiarati su LG 55UM7450PLA; compatibilità universale non garantita.
- Wake-on-LAN soltanto sulla rete locale. Il risveglio dopo standby prolungato resta da verificare: Quick Start+ non ha risolto il caso segnalato, mentre ThinQ riesce ad accendere la TV.
- Wi-Fi ed Ethernet hanno MAC diversi. Il MAC serve all’accensione, non sostituisce l’IP per i comandi.
- Comandi tramite WS porta 3000; WSS porta 3001 ancora da implementare.
- Chiavi nel Portachiavi, preferenze locali; niente analytics o account cloud.
- Controllo GitHub Releases facoltativo, disattivato inizialmente: all’avvio e ogni 24 ore mentre l’app resta aperta, oppure manualmente. Banner e notifica se autorizzata; nessun download/installazione automatico.
- Nessun servizio al login, helper o scansione TV periodica. Un solo tentativo SSDP limitato in caso di collegamento iniziale fallito, con identità della TV già nota.
- Firma ad-hoc, senza Developer ID o notarizzazione.
- Documentazione IT/EN, screenshot con dati sintetici, copertina e icone approvati da preservare.

## Novità 1.0.1

Ricerca TV SSDP e associazione guidata; indirizzo manuale opzionale. Identità SSDP salvata per ritrovare la stessa TV dopo un cambio IP; per vecchie associazioni selezionarla tramite Cerca TV una volta. Identità locale non crittograficamente autenticata.

Rilevamento MAC con wifiInfo/wiredInfo e stato delle schede: solo una scheda confermata attiva può compilare un campo vuoto. Candidati ambigui e cache ARP richiedono conferma. Broadcast calcolato dalla sottorete quando univoco.

Impostazioni TV / Accensione / App; Ripeti associazione conserva la vecchia chiave fino al successo; Rimuovi associazione richiede conferma e cancella collegamento e impostazioni di accensione. Menu sorgente allineato a destra.

## Verifiche e attività residue

Build 19, firma e ZIP verificati; binario installato identico al pacchetto. Self-test IT/EN e test helper MAC/broadcast, SSDP e aggiornamenti superati. Ricerca reale: una TV webOS rilevata. Il MAC Wi-Fi proposto è stato confrontato dall’utente con le informazioni TV ed è corretto.

Restano da verificare il recupero dopo un cambio DHCP reale, il risveglio dopo standby prolungato, la consegna di una notifica per una futura release e altri modelli TV. Consigliata prenotazione DHCP sul router; non garantisce autorizzazione permanente o risveglio.

Prima di ogni modifica futura verificare file e stato remoto. Conservare solo la copia installata come .app e archiviare le prove in ZIP per evitare duplicati nel Launchpad.
