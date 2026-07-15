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

## 3. Pubblicare su App Store (richiede Apple Developer Program, 99$/anno)

1. Iscriviti a **https://developer.apple.com/programs/** (99$/anno).
2. In Codemagic: **Team settings → Integrations → App Store Connect** → collega il tuo
   account Apple (ti chiede una API key che generi da App Store Connect, la pagina di
   Codemagic spiega dove trovarla).
3. Lancia il workflow **"Pàgina — iOS (richiede Apple Developer Program)"** → produce
   l'IPA e lo carica automaticamente su TestFlight.

## Note

- Nessuno di questi passaggi tocca il sito web pubblico su GitHub Pages: sono build
  separate, solo per le app native.
- I workflow non partono da soli a ogni push (per non consumare minuti gratuiti a ogni
  piccola modifica al sito): li avvii tu manualmente da Codemagic quando vuoi una nuova
  build da provare o pubblicare.
- Se un workflow fallisce, Codemagic ti manda una mail con il log: copiami l'errore e lo
  correggo nel codice.
