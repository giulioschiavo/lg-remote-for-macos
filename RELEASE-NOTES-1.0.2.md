# LG Remote 1.0.2

## Italiano

- Connessione WSS prioritaria, con approvazione iniziale del certificato e impronta nel Portachiavi. Certificati cambiati o rifiutati bloccati; WS di riserva solo quando la porta sicura rifiuta la connessione e non esiste un certificato approvato. Nessun ripiego per errori TLS o timeout.
- Accendi invia cinque pacchetti Wake-on-LAN a intervalli di 300 ms e si ricollega automaticamente. Accensione immediata e ricollegamento confermati dall’utente sulla LG 55UM7450PLA; standby notturno ancora da verificare.
- Stato TV aggiornato tramite eventi webOS e ping con timeout sulla connessione esistente. Nessuna scansione periodica o servizio al login.
- Impostazioni TV, Accensione e App riorganizzate; gestione della TV associata separata dalla ricerca, broadcast nelle opzioni di rete, controlli e aggiornamenti raggruppati.
- Pulsanti di collegamento rimossi dal telecomando principale: disponibili nelle impostazioni. Nuovi screenshot IT/EN nei README.

## English

- WSS preferred, with explicit first-use certificate approval and a Keychain fingerprint. Changed or rejected certificates are blocked. Legacy WS fallback only when the secure endpoint refuses the connection and no certificate is approved; never on TLS or timeout errors.
- Turn On sends five Wake-on-LAN packets at 300 ms intervals, then reconnects automatically. Immediate wake and reconnection confirmed by the user on LG 55UM7450PLA; overnight standby remains unverified.
- TV power-state events and bounded WebSocket pings keep connection state current. No periodic network discovery or login service.
- Reorganized TV, Power On and App settings, including paired-TV management, network options and grouped controls/update preferences.
- Connection actions moved from the main remote into Settings. Updated bilingual screenshots and documentation.

macOS 13+ · Apple Silicon arm64 · version 1.0.2, build 24. Ad-hoc signed, not notarized. Local network wake only; universal TV compatibility is not guaranteed. Optional GitHub update checks remain off by default, with no automatic download or installation.

SHA-256: `ba92f75896a917096e432ad87dcc9493e694317b0e695ca4bfe1286289fbee28`
