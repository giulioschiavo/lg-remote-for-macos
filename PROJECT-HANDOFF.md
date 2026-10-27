# Passaggio progetto LG Remote per macOS

Aggiornato: 27 ottobre 2026. Versione **1.0.3, build 25**, Apple Silicon arm64, macOS 13+.

## Distribuzione

Repository: https://github.com/giulioschiavo/lg-remote-for-macos
Release: https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.0.3
Pacchetto: `Downloads/LG-Remote-1.0.3-macOS-arm64.zip`.
SHA-256: `8132edfc13b13685285be48f378cb3725fb725eb1230e0830842bf852109ea84`.
Firma ad-hoc; nessun Developer ID o notarizzazione. Release pubblicata come Latest; API, download pubblico, SHA256 e binario installato verificati il 27 ottobre 2026.

## Decisioni da conservare

- Progetto personale MIT di Giulio Schiavo, indipendente da LG; sviluppo assistito dall’AI.
- Modello testato LG 55UM7450PLA; compatibilità universale non garantita.
- Wake-on-LAN solo locale; MAC della scheda attiva, distinto dall’IP usato per i comandi. Cinque pacchetti UDP9, intervalli300ms, solo premendo Accendi; successivo ricollegamento automatico.
- WSS3001 preferito. Certificato approvato esplicitamente al primo uso e impronta SHA256 nel Portachiavi. Certificato diverso o rifiutato bloccato. WS3000 solo se endpoint sicuro rifiuta la connessione e non esiste un pin; nessun downgrade per TLS, timeout o errore lettura Portachiavi. Puntatore vincolato allo stesso host e al trasporto sicuro. Rimuovi associazione elimina anche i pin.
- Eventi webOS Power Off/Suspend/Active Standby indicano standby. Screen Off resta acceso. Ping della connessione ogni8s con timeout3s. Non confondere irraggiungibile e spento.
- Nessun servizio al login, helper o discovery periodico. Un solo tentativo SSDP limitato su primo collegamento fallito con identità nota. Per vecchie associazioni, selezionare tramite Cerca TV una volta. Identità SSDP non autenticata crittograficamente.
- Chiavi nel Portachiavi; preferenze locali; niente analytics o account cloud. Controllo GitHub Releases facoltativo e disattivato inizialmente: avvio e ogni24ore mentre aperta, oppure manuale. Banner/notifica se autorizzata, nessun download/installazione automatico.
- Impostazioni TV/Accensione/App. TV associata prima della configurazione alternativa. Ricollega solo nelle impostazioni e con TV già accesa. MAC in primo piano, broadcast nelle opzioni di rete. Controlli e aggiornamenti in gruppi distinti.
- Screenshot IT/EN con dati sintetici; preservare copertina e icone approvate. Mantenere solo l’app installata come .app, prove archiviate in ZIP per evitare duplicati Launchpad.

## Verifiche

Build, firma, integrità ZIP e self-test IT/EN superati. Test di fallback TLS, riconoscimento stati standby e sequenza Wake-on-LAN/cancellazione superati. Otto screenshot renderizzati e controllati. L’utente ha confermato WSS attivo, accensione immediata dall’app e riconnessione automatica sulla TV reale.

Da verificare: risveglio dopo standby notturno, recupero dopo cambio DHCP reale, altri modelli e consegna di una notifica per una release futura. Quick Start+ da solo non ha risolto il caso notturno. Prenotazione DHCP consigliata, senza garanzia di risveglio o autorizzazione permanente.

Prima delle modifiche verificare file e stato remoto. La versione1.0.1 rimane recuperabile dalla sua release.

## Versione 1.0.3 build25 — 27 ottobre 2026

TV inizialmente irraggiungibile su3001; cinque pacchetti WoL da terminale l’hanno resa raggiungibile. Ricollegamento WSS e spegnimento dall’app confermati. Correzione: Accendi resta disponibile durante connessione; interrompe tentativo/discovery prima del burst. Timeout trasporto5s separato da autorizzazione/certificato60s; eventuale unica ricerca identità8s resta limitata. Nessun falso errore di autorizzazione per TV spenta. Pubblicazione1.0.2 conservata; questa prova non pubblicata.

- Note pubbliche1.0.3 richieste dall’utente: Small bugfix. Non sostituire1.0.2. TV spenta dopo la prova, lasciare in standby.
