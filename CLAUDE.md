# CLAUDE.md — Regole permanenti per Pàgina

Queste regole valgono per ogni sessione di lavoro su questo repository, indipendentemente
dalla richiesta specifica. Se una richiesta le contraddice, va segnalato ad Alice prima di
procedere, non ignorato in silenzio.

## Cosa NON fare senza esplicita conferma

- Non riscrivere l'app da zero né migrare a un framework diverso (Vite, React, ecc.)
  senza che Alice lo chieda esplicitamente e confermi di aver capito il rischio.
- Non aggiungere una pipeline CI/CD: il token GitHub disponibile ha solo permesso `repo`,
  non `workflow` — non è comunque possibile pubblicarla.
- Non cambiare lo schema del database senza una migration SQL versionata e separata.
- Non dichiarare un test "superato" o "eseguito" se non è stato eseguito realmente contro
  dati reali. Usare invece: "verifica statica eseguita", "test manuale richiesto",
  "migration preparata ma non applicata", "non verificabile senza accesso al database".
- Non inserire segreti (service role key, password, token) nel front-end. La chiave
  Supabase nel client deve essere sempre e solo quella pubblica/anon.
- Non usare emoji come icone strutturali (header, tab bar, badge, statistiche). Le emoji
  restano ammesse solo con reale valore decorativo/di tono nei contenuti testuali.

## Convenzioni da mantenere

- **Lingua**: tutta l'interfaccia e la comunicazione con Alice in italiano.
- **Anno dinamico**: mai scrivere un anno fisso nei componenti; sempre derivato da
  `new Date().getFullYear()` o dati reali (`bookYear`, `finished_year`, ecc.).
- **Numeri e date**: localizzazione italiana (`Intl.NumberFormat('it-IT')`, punto delle
  migliaia, date relative "oggi/ieri/N giorni fa" dove sensato).
- **Design system**: palette verde bosco/crema/ocra/salvia/blu polvere già definita nei
  token CSS (`:root` in `styles.css`); non introdurre colori diretti nei componenti,
  usare le variabili esistenti o aggiungerne di semantiche coerenti.
- **Icone**: set SVG lineare unico (`ICONS`/`icon()` in index.html), non emoji, per
  header/navigazione/badge/azioni.
- **Target di tocco**: minimo 44×44 punti per ogni elemento interattivo.
- **Compatibilità doppia**: il progetto pubblica sia come PWA web (GitHub Pages) sia come
  app nativa iOS/Android via Capacitor (`scripts/build-www.sh`). Qualunque nuovo file
  referenziato da `index.html` (CSS, JS estratti) va aggiunto anche a quello script E,
  se deve funzionare offline, alla lista `OFFLINE_URLS` in `sw.js`.
- **Struttura file**: `index.html` (markup + JS), `styles.css` (stili, estratto da
  index.html), `sw.js` (service worker), `manifest.json` (PWA). Ulteriori estrazioni
  vanno fatte una alla volta, verificando ogni volta che l'app resti funzionante
  (non estrarre struttura e modificare logica nella stessa modifica).
- **Migration SQL**: ogni cambiamento al database è un file separato e numerato in
  `supabase/migrations/`, idempotente quando possibile, mai applicato direttamente da
  Claude (nessun accesso admin al database) — sempre lanciato manualmente da Alice via
  SQL Editor, documentato in `docs/SUPABASE_MANUAL_STEPS.md`.
- **Verifica prima del commit**: `node --check` sul JavaScript estratto e controllo del
  bilanciamento parentesi del CSS, ad ogni modifica, prima di pushare.
- **Deploy**: dopo ogni push, verificare via `https://api.github.com/repos/rootliv/App/pages/builds/latest`
  che GitHub Pages abbia effettivamente pubblicato; se il deploy fallisce (instabilità nota
  dell'infrastruttura, non un problema del codice), rilanciare con un commit vuoto.
- **Cache**: bumpare `CACHE_VERSION` in `sw.js` ad ogni modifica visibile, perché iOS/PWA
  installate cachano in modo aggressivo.

## Modifiche piccole e verificabili

Procedere per incrementi piccoli, uno alla volta, mantenendo sempre una versione
funzionante. Non eseguire contemporaneamente una modifica strutturale (es. estrazione di
file) e una modifica di logica/comportamento nello stesso passaggio.

## Documentazione dei passaggi manuali

Ogni volta che una modifica richiede un'azione da parte di Alice che Claude non può
eseguire (lanciare una migration, collegare un Auth Hook dalla Dashboard, creare un
bucket Storage, ecc.), va documentata esplicitamente in chat E in
`docs/SUPABASE_MANUAL_STEPS.md`, con istruzioni chiare pensate per essere seguite da
mobile, senza terminale.
