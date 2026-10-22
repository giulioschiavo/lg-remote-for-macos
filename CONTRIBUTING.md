# Contributing / Contribuire

EN: Bug reports, compatibility reports and focused pull requests are welcome. Explain the problem, resulting behavior and validation. Keep changes small, preserve native macOS conventions, and update both `en.lproj` and `it.lproj` for user-facing strings. Run the build and `--self-test` in both languages. Do not introduce cloud dependencies for local TV commands.

IT: Sono benvenute segnalazioni, prove di compatibilità e pull request mirate. Descrivi problema, comportamento risultante e verifiche. Mantieni modifiche contenute, rispetta le convenzioni native macOS e aggiorna entrambe le lingue per i testi dell’interfaccia. Compila ed esegui `--self-test` in italiano e inglese. Non aggiungere dipendenze cloud ai comandi locali.

## Compatibility reports / Prove di compatibilità

Include TV model, webOS/firmware, macOS/app version, Wi-Fi or Ethernet, working/failing commands, pointer support and Wake-on-LAN results. Reports are observations on that configuration, not a guarantee for an entire model family.

Indica modello TV, webOS/firmware, versione macOS/app, Wi-Fi o Ethernet, comandi funzionanti/non funzionanti, puntatore e Wake-on-LAN. Un test riguarda quella configurazione, non certifica l’intera famiglia di modelli.

## Privacy

Never include pairing keys, passwords, tokens, real MAC addresses, serial numbers or unredacted logs. Use locally administered dummy MAC addresses in tests.

Non includere chiavi di associazione, password, token, MAC reali, numeri di serie o log non oscurati. Nei test usa MAC fittizi amministrati localmente.
