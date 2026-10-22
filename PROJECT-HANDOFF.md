# Passaggio progetto LG Remote per macOS

Aggiornato: 23 ottobre 2026.

## Riferimenti e versione

- Repository pubblico: https://github.com/giulioschiavo/lg-remote-for-macos
- Cartella di consegna: `publish/lg-remote-for-macos` nel workspace originale.
- Pacchetto approvato per la Release: `Downloads/LG-Remote-1.6-macOS-arm64.zip`.
- Versione 1.6, build 13; bundle `it.giulio.LGRemote`; Apple Silicon arm64, macOS 13+.
- SHA-256 ZIP: `e02357c6f8b47c5d574cf047ac4117b1a80cc9ef42ed717c8f8c7f79f35d3a5d`.

## Decisioni da preservare

- App personale gratuita, MIT, indipendente da LG; autore Giulio Schiavo, sviluppo assistito dall’AI.
- Test reali dichiarati solo su LG 55UM7450PLA; compatibilità universale non garantita.
- Accensione tramite Wake-on-LAN solo sulla rete locale, non via internet. Il pacchetto inviato non prova che la TV si sia accesa.
- Wi-Fi ed Ethernet hanno MAC distinti; usare quello della connessione attiva, non l’identificativo AirPlay.
- WebSocket attuale `ws://<TV>:3000`; `wss://` sulla 3001 non implementato.
- Chiavi nel Portachiavi, preferenze locali; nessun account cloud, analytics o controllo aggiornamenti automatico.
- Firma ad-hoc; nessuna firma Developer ID o notarizzazione.
- Touchpad relativo, senza mappatura assoluta o ricentraggio; puntatore disattivabile.
- Documentazione italiana e inglese, anteprime con dati sintetici, icone chiara/scura.

## Verifiche del 23 ottobre 2026

- Prima delle modifiche: clone remoto al commit `537580e988779e2f2d1d95bd93e50da22aee4004`; nessuna Release pubblicata.
- Sorgenti, localizzazioni, plist, script e icone remoti identici ai file locali.
- ZIP integro; versione e architettura confermate; firma verificata; self-test superato in italiano e inglese.
- Screenshot italiano controllato visivamente. README aggiornati con MAC, abilitazione accensione e link al pacchetto Release.
- Il binario in `LGRemote/dist` differisce da quello nello ZIP: non sostituire lo ZIP con una ricompilazione senza una verifica dedicata.
- La cartella publish originale aveva un repository Git senza commit e senza remoto; non usare uno stato staged come prova di pubblicazione.
- Nessun nuovo test su TV fisica eseguito durante questa ripresa.

## Consegna e attività

- COMPLETATO: Release `v1.6` pubblicata: https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.6 ; download pubblico verificato, SHA-256 identico allo ZIP originale.
- COMPLETATO: README bilingui e `docs/images/lg-remote-it.png` pubblicati nel commit `cf3b2da987f76e026861a63d8fbaaf6fa2a7e335`, a cui punta il tag v1.6.
- COMPLETATO: esito remoto conservato in questo file; la Release contiene il binario originale, senza ricompilazione.
- Futuro: test su altri modelli, WSS e discovery, controllo aggiornamenti facoltativo, Developer ID/notarizzazione, eventuale Intel.
- Per ogni modifica futura leggere prima stato remoto e file correnti; preservare testo approvato e binario distribuito.
