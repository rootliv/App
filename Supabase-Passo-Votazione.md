# Supabase — Passo per scelta libro (sorteggio + votazione) e inviti

Ho aggiunto: **link d'invito**, **sorteggio a turni** e **proposte + votazione** (il club sceglie il metodo ogni volta). Manca **un ultimo SQL** da incollare una volta.

## Cosa fare

1. Su Supabase: **SQL Editor** → **New query**.
2. Incolla questo blocco e premi **Run**:

```sql
-- Colonne per il meccanismo di scelta
alter table clubs add column if not exists selection_mode  text;     -- 'rotation' | 'voting' | null
alter table clubs add column if not exists current_chooser uuid;     -- chi sceglie (sorteggio)
alter table clubs add column if not exists cycle_choosers  uuid[] default '{}';

-- Consenti a tutti i membri del club (non solo all'owner) di aggiornare il club
drop policy if exists "club: aggiorna chi e owner" on clubs;
drop policy if exists "club: aggiorna membri" on clubs;
create policy "club: aggiorna membri" on clubs for update
  using (exists (select 1 from club_members m where m.club_id = clubs.id and m.user_id = auth.uid()))
  with check (exists (select 1 from club_members m where m.club_id = clubs.id and m.user_id = auth.uid()));

-- Proposte di libri (una per membro per club)
create table if not exists proposals (
  id bigint generated always as identity primary key,
  club_id bigint references clubs on delete cascade,
  user_id uuid references auth.users on delete cascade,
  title text, author text, cover text,
  created_at timestamptz default now(),
  unique (club_id, user_id)
);

-- Voti (uno per membro per club)
create table if not exists votes (
  club_id bigint references clubs on delete cascade,
  user_id uuid references auth.users on delete cascade,
  proposal_id bigint references proposals on delete cascade,
  created_at timestamptz default now(),
  primary key (club_id, user_id)
);

alter table proposals enable row level security;
alter table votes enable row level security;

drop policy if exists "proposte: leggi" on proposals;
create policy "proposte: leggi" on proposals for select using (auth.role() = 'authenticated');
drop policy if exists "proposte: gestisci le tue" on proposals;
create policy "proposte: gestisci le tue" on proposals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "voti: leggi" on votes;
create policy "voti: leggi" on votes for select using (auth.role() = 'authenticated');
drop policy if exists "voti: gestisci i tuoi" on votes;
create policy "voti: gestisci i tuoi" on votes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

3. **"Success. No rows returned"** = tutto a posto. ✅

## Come funziona adesso

**Link d'invito.** Nel club, pulsante **🔗 Copia link d'invito**. Chi apre il link:
- se **non è registrato** → si registra e finisce **dritto nel club**;
- se **è già registrato** → entra **direttamente nel club**.

> ⚠️ Perché il link funzioni anche per gli altri, l'app deve essere **online** (vedi `Guida-Pubblicazione.md` → GitHub Pages). Se apri l'app come file locale, il link funziona solo sul tuo computer.

**Scelta del libro (niente più "sceglie il creatore").** Nel pannello *Libro del mese* l'admin sceglie ogni volta il metodo:
- **🎲 Sorteggio a turni** — l'app estrae a caso un membro che sceglie il libro. Non si ripete finché tutti non hanno avuto il turno, poi il ciclo riparte.
- **🗳️ Avvia votazione** — ogni membro propone un libro, tutti votano (un voto a testa), l'admin chiude e **vince il più votato**, che diventa il libro del mese.

## Prova veloce
1. Crea un club, premi **🗳️ Avvia votazione** (o 🎲 Sorteggio).
2. Da un secondo account (altro browser), apri il **link d'invito**: entri nel club.
3. Proponi/vota, oppure (sorteggio) attendi il tuo turno e scegli.

Se compare un errore, mandami il messaggio esatto e lo sistemo.
