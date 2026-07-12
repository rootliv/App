# AUDIT — Pàgina

Data: 2026-07-12. Metodo: lettura diretta di index.html (5291 righe), manifest.json, sw.js,
CLAUDE.md, migrazioni in supabase/migrations/, Edge Function in supabase/functions/,
script di build (scripts/build-www.sh), package.json. Nessun accesso al database reale:
i punti che richiedono verifica sul progetto Supabase live sono segnalati come tali.

## Struttura del repository

- `index.html` (370 KB, 5291 righe): l'intera app — markup, CSS in un unico `<style>`,
  JavaScript in un unico blocco `<script>`. Nessuna build step per il web (serve così
  com'è via GitHub Pages).
- `manifest.json`, `sw.js`: PWA. Service worker con strategia network-first per i documenti
  (vedi SECURITY_REVIEW.md per la strategia dettagliata).
- `supabase/migrations/*.sql`: 6 file, applicati manualmente da Alice via SQL Editor
  (nessuna CLI/CI collegata). Copre: brute-force password (Auth Hook), RLS note anti-spoiler,
  immagine club, social (follow/inviti/libreria pubblica), controllo libro-già-letto nel club,
  sicurezza Fase 1 (profili pubblici/privati, rate limit login, membership check).
- `supabase/functions/`: 3 Edge Function TypeScript — `assistente` (chat AI), `curiosita`
  (curiosità libro), `delete-account` (cancellazione account con service role).
- `package.json` + `scripts/build-www.sh` + `scripts/native.js`: **il progetto ha anche un
  guscio nativo iOS/Android via Capacitor**, non solo la PWA web. `build-www.sh` copia
  ESPLICITAMENTE solo `index.html`, `manifest.json`, `sw.js` e `icons/` nella cartella `www/`
  che Capacitor impacchetta. Qualunque file nuovo (CSS/JS estratti) va aggiunto anche lì,
  altrimenti l'app nativa carica una pagina senza stili o senza funzioni.
- `CLAUDE.md`: vuoto (0 byte) prima di questo audit.

## Debito tecnico principale

1. **File monolitico**: un solo file da 5291 righe con markup, stile e logica intrecciati.
   Rende ogni modifica rischiosa (facile toccare qualcosa di non correlato) e impossibile
   da testare a pezzi. Gravità: alta, ma il rischio di *migrazione* è più alto del rischio
   di *convivere con la situazione attuale* — motivo per procedere a piccoli passi (Fase 2).
2. **Nessuna pipeline di build/test/lint**: nessun modo automatico di verificare che una
   modifica non rompa nulla, a parte `node --check` sul JS estratto a mano e il controllo
   di bilanciamento delle parentesi CSS (fatto ad ogni modifica in questa collaborazione,
   ma manualmente, non in CI).
3. **Doppio target di deploy** (GitHub Pages web + app nativa Capacitor) con un solo file
   sorgente: ogni estrazione di file deve aggiornare `build-www.sh` di conseguenza.
4. **Edge Function senza timeout lato client**: le chiamate all'API AI esterna in
   `assistente/index.ts` e `curiosita/index.ts` non usano `AbortController` — una risposta
   lenta o bloccata dal provider tiene la funzione (e la richiesta dell'utente) appesa
   senza limite. Fix contenuto e a basso rischio, rimandato a un intervento dedicato
   sulle Edge Function (fuori dallo scope di questa sessione, che è front-end).

## Cosa NON è un problema (verificato, non presunto)

- La chiave `SUPABASE_KEY` nel front-end (`index.html`) è la chiave **pubblica/anon**
  (`sb_publishable_...`), corretta da avere lato client: è protetta dalle policy RLS,
  non dà accesso privilegiato. Nessuna `service_role` key trovata nel front-end.
- Un solo `console.log` nel codice, ed è il marcatore di versione a scopo di debug
  (`build: vNNN`), non stampa dati sensibili.
- Nessun anno hardcoded trovato al di fuori di `new Date().getFullYear()` / `currentYear()`
  (controllo statico con grep su pattern `202[0-9]`, esclusi i falsi positivi nei colori
  esadecimali `#1e2024` ecc.).
- Le Edge Function hanno già: allowlist CORS esplicita (non `*`), rate limiting
  best-effort per istanza (documentato onestamente nei commenti come non distribuito),
  limiti di lunghezza sugli input.

## Problema pre-esistente individuato in sw.js (non corretto in questa sessione)

Il gestore `fetch` di `sw.js` usa `caches.match('./index.html')` come fallback per **qualunque**
richiesta GET della stessa origine che fallisce offline — non solo per la navigazione tra
pagine. La Fase 10 del brief di sicurezza segnala esplicitamente di non fare questo
("non mettere index.html come fallback per ogni richiesta"). È un comportamento preesistente,
non introdotto ora. Non l'ho corretto in questo incremento per non mischiare la modifica
strutturale (estrazione CSS) con una modifica di comportamento del service worker: è
proposto come intervento a parte nel prossimo IMPROVEMENT_PLAN.md (Fase 10 dedicata).

## Debiti noti già segnalati ad Alice in passato (da IMPROVEMENT_PLAN.md)

Vedi `docs/SUPABASE_MANUAL_STEPS.md` per l'elenco aggiornato dei passaggi SQL ancora da
confermare come applicati (alcuni migration potrebbero essere già state lanciate da Alice
in sessioni precedenti, ma non ho modo di verificarlo senza accesso al database).

