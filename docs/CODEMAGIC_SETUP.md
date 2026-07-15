# Costruire l'app vera (Android/iOS) con Codemagic

Il progetto ha già tutto il necessario (`android/`, `ios/`, `codemagic.yaml`). Manca solo
collegare il repository a Codemagic: un passaggio che devi fare tu, perché richiede il
tuo account — io non posso accedervi.

## 1. Primo APK Android di prova (gratis, nessun account sviluppatore richiesto)

1. Vai su **https://codemagic.io** → **Sign up** → accedi con GitHub.
2. **Add application** → scegli il repository **rootliv/App**.
3. Codemagic trova da solo `codemagic.yaml` e propone i workflow già pronti.
4. Scegli **"Pàgina — Android (debug, senza firma)"** → **Start new build**.
5. Dopo ~5-10 minuti, nella pagina della build trovi il file **.apk** da scaricare
   direttamente sul telefono. Per installarlo su Android: apri il file scaricato,
   se richiesto abilita "Installa da fonti sconosciute" nelle impostazioni.

Questo APK è solo per provare l'app sul telefono, non è quello da pubblicare sul Play Store.

## 2. Pubblicare su Google Play (richiede account sviluppatore, 25$ una tantum)

1. Crea un account su **https://play.google.com/console** (25$ una tantum).
2. In Codemagic: **Team settings → Code signing identities → Android keystore** →
   crea un nuovo keystore chiamato `pagina_keystore` (Codemagic te lo genera lui, basta
   salvarlo).
3. Lancia il workflow **"Pàgina — Android (release firmato, per Play Store)"** →
   produce un file **.aab** da caricare su Google Play Console.

## 3. Pubblicare su App Store / TestFlight (richiede Apple Developer Program, 99$/anno)

1. **Iscriviti al programma Apple**: vai su **https://developer.apple.com/programs/**,
   accedi con un Apple ID e paga i 99$/anno. Apple verifica l'identita: a volte e
   istantaneo, a volte ci mette fino a 24-48 ore. Questo e l'unico passaggio che non
   dipende da noi due: aspetta la conferma via mail prima di andare avanti.
2. **Crea una API key in App Store Connect**: su **https://appstoreconnect.apple.com** ->
   **Users and Access -> Integrations -> App Store Connect API** -> tasto **+** -> dai un
   nome a scelta, ruolo **App Manager** -> **Generate**. Poi:
   - scarica subito il file della chiave (**Download API Key**) - si puo scaricare
     una volta sola, salvalo da qualche parte sicuro;
   - annota **Issuer ID** (scritto sopra la tabella) e il **Key ID** della chiave appena
     creata.
3. **Collega la chiave a Codemagic**: **Team settings -> Integrations -> Developer Portal
   -> Manage keys -> Add key**. Chiamala esattamente **codemagic** (deve corrispondere al
   nome gia scritto nel file di configurazione del progetto), incolla Issuer ID e Key ID,
   carica il file della chiave scaricato al punto 2 -> **Save**.
4. **Crea la scheda dell'app su App Store Connect**: **My Apps -> + -> New App** ->
   piattaforma iOS, nome "Pagina", bundle ID **io.github.rootliv.pagina**. Se il bundle ID
   non compare nell'elenco, registralo prima su
   **developer.apple.com -> Certificates, Identifiers & Profiles -> Identifiers -> +**.
5. **Lancia il workflow**: su Codemagic scegli **"Pagina - iOS (richiede Apple Developer
   Program)"** -> **Start new build**. Gira su un Mac quindi ci mette di piu di Android
   (anche 20-30 minuti). Se va a buon fine, l'IPA viene caricato automaticamente su
   TestFlight: da li lo installi sul tuo iPhone tramite l'app TestFlight (gratis,
   scaricala dall'App Store).

Manda uno screenshot a ogni passaggio se qualcosa non e chiaro o non torna: ti dico io
cosa cliccare.

## Note

- Nessuno di questi passaggi tocca il sito web pubblico su GitHub Pages: sono build
  separate, solo per le app native.
- I workflow non partono da soli a ogni push (per non consumare minuti gratuiti a ogni
  piccola modifica al sito): li avvii tu manualmente da Codemagic quando vuoi una nuova
  build da provare o pubblicare.
- Se un workflow fallisce, Codemagic ti manda una mail con il log: copiami l'errore e lo
  correggo nel codice.
