-- ============================================================================
-- FASE 2 SICUREZZA — chiude tre varchi lasciati aperti da regole "vecchie",
-- scritte a mano su Supabase prima che si iniziasse a tracciare tutto nei
-- file di migration, mai rimosse quando sono arrivate quelle nuove più
-- restrittive (le regole permissive convivevano con quelle nuove e vincevano
-- loro, perché in Postgres le policy si sommano con OR: basta che UNA sia
-- permissiva perché l'accesso sia comunque concesso).
--
-- Sicura da rilanciare più volte (idempotente).
-- ============================================================================

-- Per sicurezza, mi assicuro che la protezione a livello di riga sia accesa
-- ovunque serve, indipendentemente da come sono state create le tabelle.
alter table public.profiles enable row level security;
alter table public.notes enable row level security;
alter table public.club_members enable row level security;
alter table public.clubs enable row level security;
alter table public.books enable row level security;

-- ----------------------------------------------------------------------------
-- 1) PROFILI: la regola "profili: leggi tutti" (condizione sempre vera)
--    permetteva a chiunque autenticato di leggere la riga intera di ogni
--    profilo, email compresa — anche dopo aver aggiunto la regola più
--    restrittiva "profiles_self_read". Va tolta per far valere quella nuova.
-- ----------------------------------------------------------------------------
drop policy if exists "profili: leggi tutti" on public.profiles;

-- ----------------------------------------------------------------------------
-- 2) NOTE DEL DIARIO: la protezione anti-spoiler (tabella reading_progress +
--    regola notes_select_antispoiler) non risultava mai installata. In più,
--    la vecchia regola "note: leggi se autenticato" (chiunque autenticato
--    legge tutto) l'avrebbe comunque resa inutile se solo l'avessimo
--    installata senza toglierla. Qui la installo per bene e tolgo quella
--    vecchia.
-- ----------------------------------------------------------------------------
create table if not exists public.reading_progress (
  user_id    uuid not null references auth.users(id) on delete cascade,
  club_id    bigint not null,
  book_title text not null,
  position   int  not null default 1,
  updated_at timestamptz not null default now(),
  primary key (user_id, club_id, book_title)
);

alter table public.reading_progress enable row level security;

drop policy if exists rp_select_own on public.reading_progress;
create policy rp_select_own on public.reading_progress
  for select using (auth.uid() = user_id);

drop policy if exists rp_upsert_own on public.reading_progress;
create policy rp_upsert_own on public.reading_progress
  for insert with check (auth.uid() = user_id);

drop policy if exists rp_update_own on public.reading_progress;
create policy rp_update_own on public.reading_progress
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.my_reading_position(p_club bigint, p_book text)
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

drop policy if exists notes_select_antispoiler on public.notes;
create policy notes_select_antispoiler on public.notes
  for select using (
    auth.uid() = user_id
    OR position <= public.my_reading_position(club_id, book_title)
  );

drop policy if exists notes_insert_own on public.notes;
create policy notes_insert_own on public.notes
  for insert with check (auth.uid() = user_id);

drop policy if exists notes_update_own on public.notes;
create policy notes_update_own on public.notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists notes_delete_own on public.notes;
create policy notes_delete_own on public.notes
  for delete using (auth.uid() = user_id);

-- La vecchia regola permissiva: senza toglierla, tutto il resto qui sopra
-- non avrebbe alcun effetto reale (le due regole si sommano con OR).
drop policy if exists "note: leggi se autenticato" on public.notes;

-- ----------------------------------------------------------------------------
-- 3) MEMBRI DEL CLUB: le regole attuali controllano solo "stai modificando
--    la tua riga?", non "che ruolo ti stai assegnando". Un utente poteva
--    scriversi da solo come admin di un club — anche uno a cui non
--    apparteneva — chiamando la funzione a mano invece che dai pulsanti.
--    Un trigger aggiunge il controllo sul valore del ruolo, che le regole
--    RLS da sole non possono esprimere riga per riga in questo modo.
-- ----------------------------------------------------------------------------
create or replace function public.club_members_enforce_role_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner_or_admin boolean;
begin
  if tg_op = 'INSERT' then
    if new.role = 'admin' then
      v_is_owner_or_admin := exists(
        select 1 from public.clubs where id = new.club_id and owner = auth.uid()
      );
      if not v_is_owner_or_admin then
        raise exception 'Solo il proprietario del club può registrarsi come amministratore.';
      end if;
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.role is distinct from old.role then
      v_is_owner_or_admin := exists(
        select 1 from public.clubs where id = old.club_id and owner = auth.uid()
      ) or exists(
        select 1 from public.club_members
        where club_id = old.club_id and user_id = auth.uid() and role = 'admin'
      );
      if not v_is_owner_or_admin then
        raise exception 'Solo un amministratore del club può cambiare il ruolo di un membro.';
      end if;
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists club_members_role_rules on public.club_members;
create trigger club_members_role_rules
  before insert or update on public.club_members
  for each row
  execute function public.club_members_enforce_role_rules();
