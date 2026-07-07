-- ============================================================
-- Social: libreria pubblica/privata, follow, inviti ai club
-- ============================================================

-- 1) Flag libreria pubblica sul profilo (default: privata)
alter table public.profiles add column if not exists public_library boolean not null default false;

-- Consenti a chiunque (autenticato) di cercare profili per username e vedere
-- il flag public_library. (I profili contengono già name/username: nessun dato sensibile.)
drop policy if exists profiles_search_read on public.profiles;
create policy profiles_search_read on public.profiles
  for select using (auth.role() = 'authenticated');

-- 2) Tabella follows: follower -> followed
create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id)
);
alter table public.follows enable row level security;

drop policy if exists follows_select on public.follows;
create policy follows_select on public.follows
  for select using (auth.uid() = follower_id or auth.uid() = followed_id);

drop policy if exists follows_insert on public.follows;
create policy follows_insert on public.follows
  for insert with check (auth.uid() = follower_id);

drop policy if exists follows_delete on public.follows;
create policy follows_delete on public.follows
  for delete using (auth.uid() = follower_id);

-- 3) Vedere i libri altrui SOLO se la loro libreria è pubblica E li segui.
--    (Le note personali stanno nella colonna books.note, quindi seguono la stessa regola.)
drop policy if exists books_read_public on public.books;
create policy books_read_public on public.books
  for select using (
    auth.uid() = user_id
    OR (
      exists (select 1 from public.profiles p where p.id = books.user_id and p.public_library = true)
      AND exists (select 1 from public.follows f where f.followed_id = books.user_id and f.follower_id = auth.uid())
    )
  );

-- 4) Inviti ai club per username (da accettare)
create table if not exists public.club_invites (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.clubs(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending', -- pending | accepted | declined
  created_at timestamptz not null default now(),
  unique (club_id, invitee_id)
);
alter table public.club_invites enable row level security;

-- l'invitato vede i propri inviti; l'invitante vede quelli che ha mandato
drop policy if exists club_invites_select on public.club_invites;
create policy club_invites_select on public.club_invites
  for select using (auth.uid() = invitee_id or auth.uid() = inviter_id);

-- solo un membro del club può invitare
drop policy if exists club_invites_insert on public.club_invites;
create policy club_invites_insert on public.club_invites
  for insert with check (
    auth.uid() = inviter_id
    AND exists (select 1 from public.club_members m where m.club_id = club_invites.club_id and m.user_id = auth.uid())
  );

-- l'invitato può aggiornare (accettare/rifiutare) il proprio invito
drop policy if exists club_invites_update on public.club_invites;
create policy club_invites_update on public.club_invites
  for update using (auth.uid() = invitee_id) with check (auth.uid() = invitee_id);
