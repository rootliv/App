# Pàgina — Redesign front-end: ricerca, direzione e patch

Documento di design per l'app (libreria personale, profilo lettore, letture, consigli AI). Le scelte sono basate su benchmark del settore e best practice UX/UI, non su gusti casuali.

---

## 1. Analisi dei problemi del front-end attuale

- **Identità poco distintiva**: prima sembrava una dashboard generica; per un'app di lettura le **copertine** devono essere protagoniste e l'atmosfera "da libreria".
- **Sezione "Tu" fredda**: era un insieme di campi/toggle; un profilo lettore deve raccontare *chi sei come lettrice*.
- **Stati vuoti deboli**: pagine vuote senza guida = nuovo utente disorientato.
- **Consigli AI poco "personali"**: senza motivazione esplicita non vengono percepiti come su misura.
- **Mobile non prioritario**: tap target, zoom dei campi su iOS, overflow.
- **Mancanza di tema scuro**: molto richiesto dai lettori (lettura serale).
- **Poche microinterazioni**: l'interfaccia risultava statica.

## 2. Benchmark — cosa apprezzano gli utenti

- **Goodreads**: scaffali visivi, valutazioni a stelle inline, scoperta sociale. *(Da prendere: copertine + rating immediati.)*
- **The StoryGraph**: statistiche di lettura, mood/temi, **tema scuro**, estetica minimale. *(Da prendere: dashboard con numeri chiari + dark mode.)*
- **Fable**: club del libro, community calda, copertine grandi. *(Da prendere: club e condivisione in evidenza.)*
- **Literal**: tipografia editoriale elegante, tanto spazio bianco. *(Da prendere: serif per i titoli, respiro.)*
- **Bookmory / Basmo**: tracking progresso, sessioni, gamification leggera (obiettivi, streak). *(Da prendere: obiettivo annuale, progressi.)*

**Pattern comuni amati**: copertine grandi, navigazione semplice e costante, stati vuoti che guidano, personalizzazione visibile, microinterazioni leggere, mobile fluido, dark mode.

## 3. Direzione visiva scelta — "Caldo & editoriale, ma tecnologico"

Atmosfera da libreria accogliente (crema, prugna, terracotta, serif per i titoli) unita a superfici pulite, ombre soffuse e microinterazioni moderne. Copertine al centro. Tema chiaro **e** scuro.

## 4. Palette colori

**Chiaro**
- Sfondo `#f4eee4` · superfici `#fffdf9` / `#f8f2e8` · bordi `#ece1d2`
- Inchiostro `#2a221f` · soft `#766a61` · faint `#a89d92`
- Prugna (brand) `#6d2540` → `#9a4c66` · Terracotta `#e08a5d` · Oro `#caa14a` · Salvia `#5f8d6c` · Blu `#3f739c`

**Scuro**
- Sfondo `#15110d` · superfici `#1e1813` / `#272019` · bordi `#352a21`
- Inchiostro `#f1e7da` · soft `#bcab9b`
- Accento testo (rosa chiaro) `#eca6b8` · brand fill `#a23e5d` · accenti caldi invariati

Uso semantico: **prugna** = azione primaria/brand; **terracotta** = accento/hover; **salvia** = positivo/AI match; **oro** = valutazioni; **blu** = info/online.

## 5. Tipografia

- **Fraunces** (serif "editoriale") per titoli, numeri-chiave, copertine → carattere libresco e caldo.
- **Inter** (sans) per testo e UI → massima leggibilità.
- Scala: H1 ~30–34, H2 ~23–26, titoli sezione ~17–19, corpo 14–15, micro 11.5–13. Interlinea corpo 1.55–1.75.
- Su mobile i campi sono a **16px** per evitare lo zoom automatico iOS.

## 6. Struttura layout aggiornata

- **Navigazione**: sidebar a sinistra (desktop) raggruppata in *Tu / Insieme / Strumenti*; **bottom-bar** su mobile con le 5 sezioni chiave. Stato attivo sempre evidente.
- **Home/Dashboard**: hero personalizzato (saluto + cosa fare ora) → 4 statistiche **cliccabili** (Letti / In lettura / Da leggere / Club) → "Continua a leggere" → "Ti aspettano" (azioni reali).
- **Libreria**: schede a scaffale con copertine grandi; tab Tutti / In lettura / Da leggere / Letti / **Consigli AI**; stato vuoto con invito.
- **Consigli AI** (dentro Libreria): card con copertina, autore, **motivo del consiglio** e azione "Aggiungi"; basati su profilo + libreria; varietà garantita (max 2 libri per autore).
- **Profilo ("Tu")**: header con avatar e badge (ritmo, obiettivo, club); generi/autori/libri come **chip**; obiettivo annuale con barra; niente form freddo.
- **Card libro**: copertina, titolo, autore, valutazione a stelle; dettaglio in modale con trama, azioni di stato (Inizia a leggere / Letto), note, link d'acquisto.

## 7. Componenti riutilizzabili

`.card`, `.btn` (+ `.gold` `.ghost` `.sm`), `.pill` (varianti colore), `.cover` (copertina con fallback a gradiente), `.stat`, `.tabs`, `.toggle`, `.chipopt` (selezione), `.acbox` (autocomplete), `.note`, `.event`, `.member`, `.modal` + `.modal-top`, `.skel` (skeleton). Tutti governati da **variabili CSS** → un'unica fonte per colori/raggi/ombre e per il tema chiaro/scuro.

## 8. Microinterazioni (leggere)

- Sollevamento card/copertine all'hover; pressione pulsanti; transizione barre di progresso.
- **Skeleton shimmer** durante il caricamento dei consigli AI.
- Comparsa dei contenuti in fade; menu mobile con scale al tap.
- **Focus visibile** per la tastiera e rispetto di *"riduci animazioni"* del sistema.

## 9. Mobile-first

- Bottom-bar fissa, tap target ampi, niente overflow orizzontale, campi 16px, mappa e modali adattate, griglia libri a 2 colonne sui telefoni stretti.

## 10. Cosa è GIÀ applicato in questa patch

- Sistema a **variabili CSS** + **tema chiaro/scuro** con interruttore (🌙/☀️) che ricorda la scelta.
- Palette e tipografia editoriali; ombre/raggi più morbidi.
- **Accessibilità**: focus visibile; `prefers-reduced-motion`.
- **Skeleton** animato nei consigli AI; microtransizioni su card/pillole/bottom-bar.
- (Dai passi precedenti) profilo reale e caldo, stati vuoti guidati, consigli AI con motivazione e varietà, card libro con azioni di stato, Home con statistiche cliccabili.

## 11. Checklist finale di test

**Responsive**
- [ ] 360px (telefono piccolo): nessun overflow orizzontale; bottom-bar usabile; 2 colonne libri.
- [ ] 768px (tablet): sidebar a comparsa; griglie corrette.
- [ ] 1280px+ (desktop): sidebar fissa; larghezza contenuto max 1200px.
- [ ] Campi non causano zoom su iOS (font 16px).
- [ ] Tema scuro leggibile su tutte le sezioni (pillole, note, mappa, modali).

**Funzionale**
- [ ] Registrazione/login (email o username) e logout.
- [ ] Libreria: aggiungi/ricerca, cambia stato (da leggere → in lettura → letto), valuta, nota, rimuovi.
- [ ] Home: contatori corretti e cliccabili → sezione giusta.
- [ ] Consigli AI: compaiono da profilo+libreria, con motivo, max 2 per autore, escludono i posseduti.
- [ ] Club: crea, link d'invito, unisciti, membri, scelta libro (sorteggio/votazione), diario anti-spoiler.
- [ ] Incontri: crea e visualizza; Notifiche reali.
- [ ] Interruttore tema persiste dopo refresh.

---

### Nota
Tutte le modifiche sono a livello di **front-end** (HTML/CSS + piccoli ritocchi JS): la logica (account, cloud, club, AI) è invariata. Se vuoi, il prossimo intervento mirato consigliato è una **Home in stile dashboard** con un piccolo grafico delle letture per mese (ispirazione StoryGraph) — alto impatto visivo, basso rischio.
