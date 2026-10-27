# Passaggio progetto LG Remote per macOS

Aggiornato: 27 ottobre 2026. Versione **1.0.2, build 24**, Apple Silicon arm64, macOS 13+.

## Distribuzione

Repository: https://github.com/giulioschiavo/lg-remote-for-macos
Release: https://github.com/giulioschiavo/lg-remote-for-macos/releases/tag/v1.0.2
Pacchetto: `Downloads/LG-Remote-1.0.2-macOS-arm64.zip`.
SHA-256: `ba92f75896a917096e432ad87dcc9493e694317b0e695ca4bfe1286289fbee28`.
Firma ad-hoc; nessun Developer ID o notarizzazione. Verificare lo stato pubblico della release separatamente dai file locali.

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
