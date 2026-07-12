# IMPROVEMENT_PLAN — Pàgina

Piano incrementale. Ogni voce: cosa, rischio della modifica, dipendenze, stato.
Non tutto va fatto in questa sessione — questo file traccia la sequenza consigliata
per le prossime.

## Fatto in questa sessione

- [x] Audit reale del repository (questo documento + AUDIT.md + SECURITY_REVIEW.md).
- [x] Estrazione `styles.css` da `index.html` (vedi commit dedicato) — rischio basso,
      nessuna logica toccata, solo il contenuto di `<style>` spostato in un file esterno
      con `<link rel="stylesheet">`. `build-www.sh` aggiornato per copiarlo anche nella
      build nativa Capacitor.
- [x] `docs/SUPABASE_MANUAL_STEPS.md` creato: elenco unico e ordinato di tutte le migration
      SQL in attesa di conferma/applicazione.
- [x] `docs/MANUAL_TEST_CHECKLIST.md` creato.
- [x] `CLAUDE.md` popolato con le regole permanenti del progetto.

## Prossimi passi consigliati (in ordine, uno per volta)

1. **Estrarre `app-utils.js`**: funzioni pure senza stato (es. `esc`, `normKey`, `fmtIt`,
   `largestRemainder`, `normGenre`/`normalizeGenreIt`). Rischio basso se fatto con
   attenzione all'ordine di caricamento (devono essere definite prima di essere usate).
2. **Estrarre `statistics.js`**: l'oggetto `STATS` e le funzioni di supporto (`topCount`,
   `bookYear`). Dipende dal punto 1 (usa `normGenre`).
3. **Estrarre `supabase-client.js`**: inizializzazione del client Supabase (`SUPABASE_URL`,
   `SUPABASE_KEY`, `createClient`). Basso rischio, ma va caricato PRIMA di ogni funzione
   che usa `supa`.
4. **Verificare le policy RLS reali** (punto 5 di SECURITY_REVIEW.md) prima di introdurre
   ruoli owner/admin/member — serve un export dello stato attuale da Alice.
5. **Home/Profilo/Libreria**: correzioni mirate già in gran parte applicate nelle sessioni
   precedenti (percentuali, "Senza genere", localizzazione italiana, padding inferiore,
   accessibilità delle barre). Da questa sessione: nessuna nuova modifica a queste tre
   schermate — non richieste esplicitamente in questo giro, evitato per non toccare
   contemporaneamente troppe cose (vedi regola "una modifica strutturale alla volta").
6. **Edge Function**: aggiungere `AbortController`/timeout a `assistente` e `curiosita`
   (trovato in audit, non ancora corretto).
7. **Storage per immagini club** (Fase 9 del brief): bucket + policy + upload — intervento
   a parte, richiede passaggi manuali extra da Alice (creazione bucket da dashboard).

## Cosa resta fuori scope, come da accordo esplicito con Alice

- Migrazione a Vite/TypeScript.
- GitHub Actions / CI.
- Test Playwright/Vitest dichiarati come "eseguiti" (non ho un ambiente per farli girare
  davvero contro il progetto Supabase reale).
- Modifiche dirette al database (solo migration preparate, mai applicate da me).
