# Notifiche push vere (Android) — cosa serve per farle funzionare

Oggi l'app chiede il permesso di notifiche e registra il telefono, ma dietro non
succede nulla: manca la tabella per salvare i dispositivi e il "postino" che invia
davvero la notifica. Ho scritto entrambi (migrazione SQL + Edge Function), ma per
farli funzionare servono alcuni passaggi che solo tu puoi fare (serve un account
Google/Firebase, non posso crearlo io).

Solo Android per ora: iOS richiede una configurazione diversa (capability "Push
Notifications" in Xcode) che non abbiamo ancora fatto, visto che per ora ci
concentriamo su Android.

## 1. Lancia la migrazione SQL

Vedi `docs/SUPABASE_MANUAL_STEPS.md`, punto 7 — stessa procedura delle altre volte
(SQL Editor → New query → incolla → Run), con un'unica cosa da modificare tu prima
di lanciarla: sostituire `INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY` con la tua vera
service_role key (Dashboard Supabase → **Project Settings → API** → sezione
"Project API keys" → `service_role` → **Reveal** e copia). Questa chiave è diversa
da quella "anon/publishable" usata nel sito: non va mai messa nel codice del sito,
solo qui nel database.

## 2. Crea un progetto Firebase (gratis)

1. Vai su **https://console.firebase.google.com** → **Aggiungi progetto** → dagli un
   nome (es. "Pagina") → completa la creazione (puoi disattivare Google Analytics,
   non serve).
2. Dentro il progetto: icona ingranaggio → **Impostazioni progetto** → scheda
   **Cloud Messaging** → verifica che sia attivo (di solito lo è già).
3. Aggiungi l'app Android al progetto Firebase: **Aggiungi app → Android** →
   Package name: **io.github.rootliv.pagina** (deve combaciare esattamente) → registra
   l'app → scarica il file **google-services.json** che ti propone → mandamelo (o
   caricalo nel repository in `android/app/google-services.json`), lo aggiungo io alla
   build.

## 3. Genera l'account di servizio (per inviare le notifiche dal server)

1. Sempre in **Impostazioni progetto → Account di servizio**.
2. **Genera nuova chiave privata** → conferma → si scarica un file `.json`.
3. Questo file contiene una chiave segreta: non condividerlo pubblicamente, non va
   nel repository. Serve solo per il prossimo passaggio.

## 4. Carica l'Edge Function e il secret su Supabase

Questa parte richiede l'interfaccia a riga di comando di Supabase (o l'editor delle
Edge Function nel Dashboard, se preferisci incollare il codice lì). Il codice della
funzione è già pronto in `supabase/functions/send-push/index.ts` nel repository.

Se hai il Supabase CLI installato su un computer:
```
supabase functions deploy send-push
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat percorso/del/file-account-servizio.json)"
```

Se preferisci farlo da telefono/browser senza riga di comando, fammi sapere: ti guido
passo passo nell'editor Edge Function del Dashboard Supabase (si incolla il codice
direttamente lì, e i secret si impostano da un modulo).

## 5. Ricompila l'app Android

Una volta aggiunto `google-services.json` al progetto, serve un nuovo build Codemagic
perché il file venga incluso nell'APK.

## Come si prova

Invita qualcuno a un tuo club (dalla ricerca utenti, non dal link copiato): se tutto è
collegato, quella persona riceve una notifica push sul telefono (se ha l'app installata
e ha dato il permesso di notifiche), anche ad app chiusa.

Se qualcosa non arriva, mandami l'errore che vedi (o dimmi semplicemente "non arriva
niente") e controllo i log della funzione.
