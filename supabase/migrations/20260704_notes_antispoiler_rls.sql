-- ============================================================================
-- Protezione anti-spoiler REALE delle note del diario condiviso (a livello DB).
--
-- Problema risolto: finora il testo di TUTTE le note di un club arrivava al
-- browser e le note "non ancora raggiunte" erano nascoste solo con un blur CSS.
-- Chiunque ispezionasse la risposta di rete poteva leggere gli spoiler.
--
-- Soluzione: Row Level Security su public.notes che consente a un utente di
-- leggere una nota altrui SOLO se la sua pagina di lettura di quel libro è >=
-- alla posizione (position) della nota. Le proprie note sono sempre leggibili.
-- La pagina di lettura vive in una tabella dedicata (reading_progress), così il
-- database può verificarla: non basta più il localStorage del client.
--
-- PASSI MANUALI DOPO AVER APPLICATO QUESTA MIGRATION:
--   Nessuno: le policy si attivano da sole. Assicurati solo che il frontend
--   scriva la posizione di lettura in reading_progress (già fatto lato app).
-- ============================================================================

-- 1) Tabella con la pagina di lettura per (utente, club, libro).
create table if not exists public.reading_progress (
  user_id    uuid not null references auth.users(id) on delete cascade,
  club_id    uuid not null,
  book_title text not null,
  position   int  not null default 1,
  updated_at timestamptz not null default now(),
  primary key (user_id, club_id, book_title)
);

alter table public.reading_progress enable row level security;

-- Ognuno gestisce solo il proprio progresso di lettura.
drop policy if exists rp_select_own on public.reading_progress;
create policy rp_select_own on public.reading_progress
  for select using (auth.uid() = user_id);

drop policy if exists rp_upsert_own on public.reading_progress;
create policy rp_upsert_own on public.reading_progress
  for insert with check (auth.uid() = user_id);

drop policy if exists rp_update_own on public.reading_progress;
create policy rp_update_own on public.reading_progress
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 2) Funzione helper: pagina di lettura dell'utente corrente per un dato libro/club.
create or replace function public.my_reading_position(p_club uuid, p_book text)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select position from public.reading_progress
      where user_id = auth.uid() and club_id = p_club and book_title = p_book),
    1);
$$;

-- 3) RLS sulle note: abilita e ridefinisci le policy di lettura in chiave anti-spoiler.
alter table public.notes enable row level security;

-- SELECT: puoi leggere una nota se è tua, OPPURE se la tua pagina di lettura di
-- quel libro ha raggiunto/superato la posizione della nota.
drop policy if exists notes_select_antispoiler on public.notes;
create policy notes_select_antispoiler on public.notes
  for select using (
    auth.uid() = user_id
    OR position <= public.my_reading_position(club_id, book_title)
  );

-- INSERT/UPDATE/DELETE: solo l'autore agisce sulle proprie note.
drop policy if exists notes_insert_own on public.notes;
create policy notes_insert_own on public.notes
  for insert with check (auth.uid() = user_id);

drop policy if exists notes_update_own on public.notes;
create policy notes_update_own on public.notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists notes_delete_own on public.notes;
create policy notes_delete_own on public.notes
  for delete using (auth.uid() = user_id);

-- Nota: la policy di SELECT usa la posizione dal DB, quindi anche una richiesta
-- costruita a mano (bypassando l'interfaccia) NON può leggere le note oltre la
-- propria pagina di lettura. Il blur CSS resta solo come cortesia visiva.
