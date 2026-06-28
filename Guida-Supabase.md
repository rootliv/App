# Guida passo-passo: configurare Supabase per l'app "Pàgina"

Questa guida ti porta dall'iscrizione fino ad avere tutto pronto. **Non devi scrivere codice**: dove serve, ti faccio copiare e incollare. Tempo richiesto: circa 15–20 minuti.

> **A cosa serve Supabase.** È il "cervello in cloud" dell'app: gestisce gli account veri (con email e password) e conserva i dati online. Così potrai accedere da telefono *e* computer, e soprattutto i **club potranno essere davvero condivisi** tra persone diverse. Ha un **piano gratuito** più che sufficiente per provare e far usare l'app a un primo gruppo di amici.

---

## Passo 1 — Crea l'account

1. Vai su **https://supabase.com** e clicca **Start your project** (in alto a destra).
2. Iscriviti con **GitHub** (se ce l'hai) oppure con **email e password**.
3. Conferma l'email se richiesto.

## Passo 2 — Crea il progetto

1. Una volta dentro, clicca **New project**.
2. Compila:
   - **Name**: `pagina`
   - **Database Password**: clicca *Generate a password* e poi **SALVALA** in un posto sicuro (es. note del telefono). Ti servirà solo in casi rari, ma è importante non perderla.
   - **Region**: scegli quella più vicina (per l'Italia va bene **West EU (Frankfurt)** o **Central EU**).
3. Clicca **Create new project** e aspetta 1–2 minuti che venga preparato (vedrai una rotellina).

## Passo 3 — Attiva l'accesso via email

1. Nel menu a sinistra apri **Authentication** → **Sign In / Providers** (o **Providers**).
2. Assicurati che **Email** sia **attivo** (Enabled).
3. *Solo per la fase di test*, per accedere subito senza dover confermare ogni email: cerca l'opzione **"Confirm email"** e **disattivala**. (La riattiveremo quando l'app sarà pubblica.)
4. Salva.

## Passo 4 — Crea le tabelle (copia e incolla)

Questa è la parte che sembra tecnica, ma per te è solo *incolla e premi un bottone*.

1. Nel menu a sinistra apri **SQL Editor**.
2. Clicca **New query**.
3. **Copia tutto** il blocco qui sotto e incollalo nel riquadro:

```sql
-- Profili lettore
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  name text,
  created_at timestamptz default now()
);

-- Libreria personale
create table books (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade not null,
  title text not null,
  author text,
  genre text,
  pages int default 0,
  status text default 'toread',
  progress int default 0,
  rating int default 0,
  cover_url text,
  plot text,
  note text,
  created_at timestamptz default now()
);

-- Club del libro
create table clubs (
  id bigint generated always as identity primary key,
  name text not null,
  emoji text default '📖',
  description text,
  owner uuid references auth.users on delete set null,
  created_at timestamptz default now()
);

-- Membri dei club (con ruolo)
create table club_members (
  club_id bigint references clubs on delete cascade,
  user_id uuid references auth.users on delete cascade,
  role text default 'membro',
  primary key (club_id, user_id)
);

-- Note del diario condiviso
create table notes (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users on delete cascade not null,
  club_id bigint references clubs on delete cascade,
  book_title text,
  position int default 0,
  text text,
  shared boolean default true,
  created_at timestamptz default now()
);

-- Sicurezza: ognuno gestisce i propri dati
alter table profiles enable row level security;
alter table books enable row level security;
alter table clubs enable row level security;
alter table club_members enable row level security;
alter table notes enable row level security;

create policy "profili: leggi tutti" on profiles for select using (true);
create policy "profili: modifica il tuo" on profiles for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "libri: solo i tuoi" on books for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "club: leggi se autenticato" on clubs for select using (auth.role() = 'authenticated');
create policy "club: crea se autenticato" on clubs for insert with check (auth.role() = 'authenticated');

create policy "membri: leggi se autenticato" on club_members for select using (auth.role() = 'authenticated');
create policy "membri: gestisci la tua iscrizione" on club_members for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "note: leggi se autenticato" on notes for select using (auth.role() = 'authenticated');
create policy "note: gestisci le tue" on notes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

4. Clicca **Run** (in basso a destra). Se vedi **"Success. No rows returned"**, è andato tutto bene. ✅
   (Se rilanci e dà errore "already exists", significa che le tabelle ci sono già: nessun problema.)

## Passo 5 — Copia le due chiavi che mi servono

1. Nel menu a sinistra apri **Project Settings** (l'ingranaggio) → **API**.
2. Copia la **Project URL** (è tipo `https://abcdxyz.supabase.co`).
3. Apri la scheda **API Keys** e copia la **Publishable key** (inizia con `sb_publishable_...`).
   *(Se vedi ancora solo la vecchia "anon public key", va bene anche quella per ora.)*

---

## Cosa inviarmi

Quando hai finito, incollami qui:

1. **Project URL** → `https://........supabase.co`
2. **Publishable key** → `sb_publishable_........`

Con questi due valori collego l'app a Supabase: trasformo la schermata di accesso in un **login vero**, sposto la libreria e i club nel cloud e abilito la **condivisione reale tra membri**.

## ⚠️ Importante per la sicurezza

- La **Project URL** e la **Publishable key** sono pensate per stare dentro l'app: **puoi condividerle con me** senza problemi.
- **NON** condividere mai la **Database Password** (Passo 2) né la chiave chiamata **secret** / **service_role**: quelle restano private e devono rimanere solo tue.

---

*Fonti ufficiali Supabase per i passaggi e le nuove chiavi:*
- Chiavi API (publishable/secret): https://supabase.com/docs/guides/getting-started/api-keys
- Migrazione alle nuove chiavi: https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys
- Avvio rapido API: https://supabase.com/docs/guides/api/quickstart
