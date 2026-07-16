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

## 6. `20260712_security_phase1.sql` — ESEGUITA (confermato il 16/07)
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

## 8. `20260716_club_members_unique.sql` — DA LANCIARE (priorità alta)

Impedisce a un lettore di comparire due volte come membro dello stesso club (prima non
c'era nessun vincolo: un doppio tocco su "Unisciti" o "Accetta invito" poteva creare una
riga duplicata). La migration prima ripulisce eventuali duplicati già presenti nel
database, poi aggiunge il vincolo. Indipendente dagli altri punti.

## Colonna mancante segnalata in sessioni precedenti

Se non l'hai già fatto, serve anche (non è in un file di migration separato, va lanciata
a parte nel SQL Editor):

```sql
alter table public.books add column if not exists finished_year int;
```

Serve per l'anno di lettura dei libri (funzione "Libreria per anno", "Il tuo anno di
lettura" in Home e Profilo). Senza questa colonna, l'app funziona ma l'anno di
completamento dei libri non si salva in modo permanente.

## 9. `20260717_club_admin_only_selection.sql` — DA LANCIARE (priorità alta)

Impedisce a un membro qualsiasi (non admin) di avviare/annullare il sorteggio o la
votazione del club, o di forzarne la chiusura, chiamando le funzioni a mano invece che
dal pulsante (che già le mostra solo agli admin in interfaccia, ma finora il database non
lo controllava davvero). Chi in quel momento ha il turno di scegliere il libro nel
sorteggio resta comunque libero di farlo — è l'unico caso in cui un membro normale scrive
legittimamente su questi campi. Foto e descrizione del club restano modificabili da tutti
i membri, come deciso in precedenza.

## 10. `20260718_security_phase2.sql` — ESEGUITA (confermato il 16/07)

Chiude tre varchi scoperti fotografando le regole reali del database (punto 11 qui sotto):
regole "vecchie" scritte a mano prima di questo elenco, mai tolte quando sono arrivate
quelle nuove più restrittive, che le rendevano inefficaci:

- una regola su `profiles` permetteva ancora a chiunque autenticato di leggere la riga
  intera di ogni profilo (il fix del punto 6 in pratica non aveva effetto reale finché
  questa restava attiva insieme alla nuova);
- la protezione anti-spoiler delle note (dal punto 2) non era mai stata installata
  davvero: mancavano sia la tabella `reading_progress` sia la regola giusta, e la vecchia
  regola permissiva l'avrebbe comunque resa inutile anche installandola senza toglierla;
- un membro qualsiasi di un club poteva scriversi da solo come amministratore (anche di un
  club a cui non apparteneva), perché nessuna regola controllava il valore del ruolo
  scelto, solo che stesse modificando la propria riga.

## 11. `20260719_visibility_hardening.sql` — DA LANCIARE

Restringe l'elenco membri e gli incontri dei club a chi ne fa davvero parte: prima
qualsiasi utente autenticato poteva vedere chi è iscritto a un club qualunque, o leggere
data/luogo degli incontri di club a cui non appartiene.

## 12. Verifica delle regole di sicurezza (RLS) — nessun file da lanciare, solo da leggere

Alcune regole di sicurezza del database (chi può leggere/modificare libri, club, proposte,
voti) sono state scritte direttamente nel pannello Supabase in un momento precedente
all'uso di questo elenco, quindi non esistono come file di migration qui nel repository:
non è possibile verificarle leggendo il codice.

Per fotografarle ed eventualmente sistemarle, lancia questa query nel SQL Editor (sola
lettura, non modifica nulla) e copia il risultato:

```sql
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd;
```

Incolla il risultato in chat: da lì si può controllare se `books`, `clubs`, `proposals`
e `votes` hanno regole di scrittura (insert/update/delete) corrette — in particolare se
un lettore può modificare o cancellare solo le proprie righe — e si può preparare una
migration "di fotografia" da salvare qui nel repository per tenerne traccia stabilmente.

## Come procedere, passo per passo da mobile

1. Apri il sito di Supabase dal browser del telefono, accedi al progetto.
2. Menu laterale → **SQL Editor** → **New query**.
3. Apri uno dei file elencati sopra (dal repository GitHub, tab "raw" per copiarlo pulito).
4. Incolla tutto il contenuto nella query, premi **Run**.
5. Se vedi un errore che dice che qualcosa "already exists" per un oggetto che *non* è
   una funzione (`create or replace function` non dà mai questo errore), è normale se il
   passaggio era già stato fatto: puoi ignorarlo e passare al successivo.
6. Ripeti per ogni file, nell'ordine numerato sopra.
