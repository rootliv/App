# Mettere "Pàgina" online e aggiornarla con un clic

La tua app è un **unico file** (`index.html`): facilissima da pubblicare. Qui trovi due cose:
1. Come metterla online (GitHub Pages).
2. Come **aggiornarla senza ricaricare il file ogni volta** (la parte che ti interessa).

> **Cosa otterrai:** un link tipo `https://tuonome.github.io/pagina/` apribile ovunque, anche da telefono. E ogni volta che io modifico l'app, a te basterà **un clic** per mandarla online.

---

## ✅ Metodo consigliato: la cartella App diventa il repository (aggiornamenti "live")

L'idea: invece di ricaricare `index.html` a mano, colleghiamo **questa stessa cartella** (App) a GitHub con un programma gratuito. Io modifico i file qui dentro; tu premi **Push** e in ~1 minuto è online.

### 1. Installa GitHub Desktop
- Vai su **https://desktop.github.com** → scarica e installa **GitHub Desktop**.
- Aprilo e **accedi** con il tuo account GitHub (o creane uno gratis su https://github.com).

### 2. Collega la cartella App a GitHub
1. In GitHub Desktop: menu **File → Add Local Repository**.
2. Scegli la cartella **App** (quella dove sto lavorando: `Claude/Projects/App`).
3. Ti dirà che non è ancora un repository: clicca **"create a repository"** (crea un repository).
4. Lascia il nome `pagina` (o come vuoi) → **Create Repository**.
5. In alto comparirà **Publish repository**: cliccalo. **Togli la spunta** "Keep this code private" (deve essere pubblico per GitHub Pages) → **Publish**.

### 3. Attiva GitHub Pages
1. Vai su **https://github.com** → apri il repository `pagina`.
2. **Settings** → menu a sinistra **Pages**.
3. **Source**: "Deploy from a branch" → **Branch: main** / cartella **/(root)** → **Save**.
4. Dopo ~1 minuto, in alto comparirà il link **"Your site is live at …"**. Quello è la tua app online. 🎉

### 4. Da qui in poi: aggiornare = un clic
Ogni volta che ti dico "ho aggiornato l'app":
1. Apri **GitHub Desktop** (vedrai elencate le modifiche ai file).
2. In basso a sinistra scrivi due parole nella casella (es. "aggiornamento") e clicca **Commit to main**.
3. In alto clicca **Push origin**.
4. Aspetta ~1 minuto: il sito online è aggiornato. ✅ Niente più caricamenti manuali.

> Vuoi ridurre anche quei clic? In GitHub Desktop puoi tenere aperto il programma; appena vedi modifiche, è solo **Commit → Push**. Non esiste un "salva automatico" ufficiale senza strumenti tecnici, ma due clic è il minimo pratico e sicuro.

---

## Perché serve il tuo clic (e non lo faccio io da solo)
Io posso **modificare i file** nella cartella App, ma **non posso accedere al tuo account GitHub** né gestire le tue password o token: per sicurezza non devo mai farlo. Il "Push" è il momento in cui **tu autorizzi** la pubblicazione. Così le chiavi restano tue e nessuno può pubblicare a tuo nome.

---

## Alternativa rapida senza installare nulla (Netlify Drop)
Se non vuoi installare GitHub Desktop:
- Vai su **https://app.netlify.com/drop** e **trascina la cartella App**. Ti dà subito un link online.
- Per aggiornare, ritrascini la cartella. (Crea un account gratuito per conservare il sito.)

## Alternativa manuale (vecchio metodo)
Su https://github.com → repository → **Add file → Upload files** → trascini `index.html` → **Commit**. Funziona, ma devi rifarlo a ogni modifica: per questo consiglio il metodo con GitHub Desktop.

---

## Note utili
- Il file deve chiamarsi **`index.html`** (lo è già) per aprirsi da solo all'indirizzo del sito.
- Nella cartella ci sono anche i file guida `.md`: finiranno anch'essi su GitHub (sono innocui). Se preferisci non pubblicarli, puoi eliminarli dal repository — dimmelo e ti preparo un file `.gitignore` per escluderli.
- La **Publishable key** di Supabase dentro `index.html` può stare online senza problemi (è fatta per questo). La *Database password* e la chiave *secret* non sono nel file e non devono mai finirci.
- Il **link d'invito ai club** funziona per gli altri solo quando l'app è online (con questo metodo lo sarà).

Se ti blocchi in uno dei passaggi, dimmi a quale punto sei e ti guido di lì.
