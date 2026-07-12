# SECURITY_REVIEW — Pàgina

Per ogni voce: file/funzione coinvolta, gravità, rischio, azione, stato.

## Corretti in questa sessione (codice già in index.html + migration preparata)

### 1. `profiles.email` leggibile da qualsiasi utente autenticato
- **File**: index.html (funzioni `doSearchUsers`, `doSearchInvitees`) + policy RLS su Supabase.
- **Gravità**: alta. Non teorica: la policy `profiles_search_read` permetteva `select *` su
  tutti i profili a chiunque loggato, e il client selezionava esplicitamente la colonna `email`.
- **Azione**: policy ristretta a riga propria; creata vista `public_profiles` (solo colonne
  non sensibili); rimossa la ricerca persone per email; ~8 punti del client migrati alla vista.
- **Stato**: codice applicato e pushato (build v111). **Migration SQL preparata ma non
  applicata da me** — va lanciata da Alice: `supabase/migrations/20260712_security_phase1.sql`.

### 2. `club_member_read_book` senza controllo membership
- **Gravità**: media-alta. Chiunque autenticato poteva interrogare la cronologia di lettura
  di un club a cui non apparteneva.
- **Azione**: la funzione ora verifica `auth.uid()` sia tra i membri del club prima di
  restituire qualunque dato.
- **Stato**: nella stessa migration di cui sopra, non ancora applicata da Alice.

### 3. Login per username senza rate limiting dedicato
- **Gravità**: media. La protezione brute-force esistente (migration 20260701) agisce solo
  sulla *verifica password*, non sul lookup username→email, che quindi restava un oracolo
  per raccogliere email in massa provando molti username.
- **Azione**: tabella `username_lookup_attempts` con backoff, dentro la funzione
  `email_for_login` (SECURITY DEFINER); messaggi di errore unificati lato client.
- **Stato**: stessa migration, non applicata da Alice.

## Trovati ora, NON ancora corretti (proposti per una prossima sessione)

### 4. Edge Function senza `AbortController`/timeout
- **File**: `supabase/functions/assistente/index.ts`, `supabase/functions/curiosita/index.ts`.
- **Gravità**: bassa-media (disponibilità, non riservatezza). Una chiamata lenta al
  provider AI esterno può tenere la function (e il client in attesa) senza limite di tempo.
- **Azione consigliata**: aggiungere `AbortController` con timeout (es. 20s) sulla `fetch`
  verso il provider AI.
- **Stato**: non applicato. È un file server-side separato da index.html: applicabile con
  rischio contenuto in un intervento dedicato, ma richiede poi il redeploy della function
  (comando Supabase CLI che io non posso eseguire — passaggio manuale per Alice).

### 5. Ruoli club non ancora granulari (owner/admin/member con RPC dedicate)
- **Gravità**: media. Oggi il controllo ruolo esiste (`myRoles[c.id]==='admin'` lato client
  in più punti), ma non ho verificato a fondo se OGNI operazione di scrittura sui club ha
  una RLS/RPC server-side equivalente che impedisce a un membro semplice di eseguire azioni
  da admin bypassando il client (es. chiamando direttamente l'API REST di Supabase).
- **Stato**: **non verificato in questa sessione** — richiede di rileggere tutte le policy
  RLS attualmente attive su `clubs`/`club_members`/`meetings`/`proposals`/`votes`, cosa che
  non posso fare senza accesso diretto al database (le migration nel repo sono solo quelle
  che io ho scritto in sessioni precedenti; potrebbero essercene altre applicate a mano da
  Alice via dashboard che non sono tracciate qui). Prossimo passo proposto: chiedere ad
  Alice un export delle policy attuali (`select * from pg_policies`) per un audit reale
  invece di assumere lo stato dal solo codice client.

### 6. Immagini club in base64 nel database
- **Gravità**: bassa (prestazioni/costo, non sicurezza diretta) ma il brief la segnala.
- **Stato**: non affrontato in questa sessione (Fase 9, richiede Supabase Storage +
  policy dedicate + funzione di upload — intervento a parte).

## Cose verificate come NON problematiche

- Nessuna `service_role` key nel front-end.
- CORS delle Edge Function con allowlist esplicita (non `*`).
- Rate limiting best-effort già presente sulle Edge Function (limite: per-istanza, non
  distribuito — già documentato onestamente nei commenti del codice esistente).

## Legenda stato

- **Applicato**: codice nel repo, migration pronta ma da lanciare manualmente.
- **Non applicato**: solo individuato, nessuna modifica al codice.
- **Non verificabile**: richiede accesso al database live che non ho.
