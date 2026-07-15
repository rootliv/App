# SUPABASE_MANUAL_STEPS — Pàgina

Ogni migration va lanciata dal **SQL Editor** di Supabase, nell'ordine indicato. Sono
idempotenti dove possibile (rilanciarle non fa danni), ma vanno comunque eseguite una
volta per essere attive: scrivere il file nel repository NON le applica al database.

Non ho modo di sapere da qui quali di queste sono già state lanciate nelle sessioni
precedenti: questo elenco è ricostruito dai file presenti in `supabase/migrations/`.
Se un passaggio dà errore perché l'oggetto esiste già, va bene: vuol dire che era
già stato applicato.

## 1. `20260701_password_brute_force_protection.sql`
Protezione anti brute-force sulle password. **Dopo averla lanciata**, va anche collegata
manualmente: Dashboard → Authentication → Hooks → "Password Verification Hook" →
seleziona `public.hook_password_verification_attempt`. Il file SQL da solo non basta.

## 2. `20260704_notes_antispoiler_rls.sql`
RLS per le note del diario condiviso anti-spoiler.

## 3. `20260706_club_image.sql`
Colonna immagine dei club.

## 4. `20260707_social.sql`
Follow, inviti ai club, libreria pubblica/privata.

## 5. `20260709_club_read_check.sql`
Funzione che verifica se un libro è già stato letto da un membro del club.
**Nota**: questa versione è stata sostituita dalla numero 6 (più sicura, controlla la
membership del chiamante). Se lanci la 6 dopo, va bene lo stesso rilanciare anche questa
prima — `create or replace function` sovrascrive senza errori.

## 6. `20260712_security_phase1.sql` — DA LANCIARE (priorità alta)
La più recente e la più importante rimasta in sospeso. Contiene:
- restrizione della lettura dei profili (email non più visibile ad altri utenti);
- vista `public_profiles` per le ricerche;
- limite ai tentativi di login per username;
- correzione della funzione che controlla se un libro è già stato letto nel club
  (ora verifica che tu sia davvero membro di quel club);
- funzione per controllare se uno username è già preso, senza esporre altri dati.

**Se non la lanci**: il codice già pubblicato (build v111+) continua a funzionare per le
parti che non dipendono da queste funzioni, ma le ricerche di persone e il controllo
username potrebbero non funzionare finché le funzioni `public_profiles` /
`is_username_taken` non esistono sul database. Vanno lanciate insieme, sono nello stesso
file.

## 7. `20260715_push_notifications.sql` — nuovo, per le notifiche push Android

Crea la tabella `device_tokens` (dove il telefono salva il proprio token dopo aver dato
il permesso di notifiche) e un trigger che, quando arriva un nuovo invito a un club,
chiama in automatico una funzione che invia la notifica push. **Prima di lanciarla**,
sostituisci nel file `INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY` con la tua vera service_role
key (Dashboard -> Project Settings -> API). Indipendente dagli altri punti di questo
elenco: puoi lanciarla anche se non hai ancora fatto il punto 6.

Da sola non basta a far arrivare le notifiche: serve anche un progetto Firebase e la
Edge Function collegata. Guida completa in `docs/NOTIFICHE_PUSH_SETUP.md`.

## Colonna mancante segnalata in sessioni precedenti

Se non l'hai già fatto, serve anche (non è in un file di migration separato, va lanciata
a parte nel SQL Editor):

```sql
alter table public.books add column if not exists finished_year int;
```

Serve per l'anno di lettura dei libri (funzione "Libreria per anno", "Il tuo anno di
lettura" in Home e Profilo). Senza questa colonna, l'app funziona ma l'anno di
completamento dei libri non si salva in modo permanente.

## Come procedere, passo per passo da mobile

1. Apri il sito di Supabase dal browser del telefono, accedi al progetto.
2. Menu laterale → **SQL Editor** → **New query**.
3. Apri uno dei file elencati sopra (dal repository GitHub, tab "raw" per copiarlo pulito).
4. Incolla tutto il contenuto nella query, premi **Run**.
5. Se vedi un errore che dice che qualcosa "already exists" per un oggetto che *non* è
   una funzione (`create or replace function` non dà mai questo errore), è normale se il
   passaggio era già stato fatto: puoi ignorarlo e passare al successivo.
6. Ripeti per ogni file, nell'ordine numerato sopra.
