-- ============================================================================
-- NOTIFICHE VERE (persistenti)
--
-- PERCHÉ
-- Finora la sezione Notifiche non registrava nulla: ricostruiva uno "stato
-- attuale" a ogni apertura (es. "Diario condiviso: aggiungi una nota" restava
-- lì per sempre, non era un avviso). Niente storico, niente vero letto/non letto,
-- il puntino della campanella inaffidabile.
--
-- COSA FA QUESTA MIGRATION
-- Crea una tabella `notifications`: ogni evento reale (invito a un club, invito
-- accettato, nuovo follower, libro scelto, nuova nota, incontro creato, votazione
-- aperta) scrive UNA riga, indirizzata all'utente giusto. L'app la legge, la marca
-- letta, la cancella. È la stessa riga che alimenta anche la push (quando l'utente
-- ha attivato le push): un solo punto di verità.
--
-- SICUREZZA
-- RLS attiva: ognuno vede/aggiorna/cancella SOLO le proprie notifiche. Nessuno
-- può inserire notifiche per altri dal client: l'inserimento avviene solo lato
-- database, tramite la funzione SECURITY DEFINER `notify()` chiamata dai trigger.
--
-- Idempotente: si può rilanciare senza danni.
-- ============================================================================

create table if not exists public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,                 -- 'invite' | 'invite_accepted' | 'follower' | 'book' | 'note' | 'meeting' | 'vote'
  title      text not null,
  body       text not null default '',
  club_id    bigint,                        -- opzionale: per aprire il club/diario giusto
  actor_id   uuid,                          -- chi ha generato l'evento (per non notificare se stessi)
  dedup_key  text,                          -- evita doppioni dello stesso evento
  read_at    timestamptz,                   -- null = non letta
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on public.notifications(user_id, created_at desc);
-- Un dato evento non deve generare due righe uguali per lo stesso utente.
create unique index if not exists notifications_dedup_idx
  on public.notifications(user_id, dedup_key) where dedup_key is not null;

alter table public.notifications enable row level security;

-- Ognuno vede solo le proprie.
drop policy if exists notifications_own_read on public.notifications;
create policy notifications_own_read on public.notifications
  for select using (auth.uid() = user_id);

-- Ognuno può marcare lette / gestire solo le proprie.
drop policy if exists notifications_own_update on public.notifications;
create policy notifications_own_update on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists notifications_own_delete on public.notifications;
create policy notifications_own_delete on public.notifications
  for delete using (auth.uid() = user_id);

-- NIENTE policy di INSERT: dal client non si inseriscono notifiche.
-- L'inserimento passa solo da questa funzione, che gira coi privilegi del
-- proprietario (SECURITY DEFINER) ed è chiamata dai trigger di sistema.
create or replace function public.notify(
  p_user uuid, p_kind text, p_title text, p_body text default '',
  p_club bigint default null, p_actor uuid default null, p_dedup text default null
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications(user_id, kind, title, body, club_id, actor_id, dedup_key)
  select p_user, p_kind, p_title, coalesce(p_body,''), p_club, p_actor, p_dedup
  where p_user is not null
    and (p_actor is null or p_actor <> p_user)   -- non notificare l'autore dell'evento
  on conflict do nothing;                          -- dedup: stesso evento, una riga sola
$$;

revoke all on function public.notify(uuid,text,text,text,bigint,uuid,text) from public, anon;
-- Eseguibile solo internamente (dai trigger). Non serve concederla al client.

grant select, update, delete on public.notifications to authenticated;

-- ----------------------------------------------------------------------------
-- TRIGGER: gli eventi reali scrivono una notifica
-- ----------------------------------------------------------------------------

-- 1) Invito a un club (ricevuto)
create or replace function public.notif_on_invite() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; iname text;
begin
  select name into cname from public.clubs where id = new.club_id;
  select coalesce(username, name, 'Un lettore') into iname from public.profiles where id = new.inviter_id;
  perform public.notify(
    new.invitee_id, 'invite',
    'Invito a un club',
    iname || ' ti ha invitato in «' || coalesce(cname,'un club') || '».',
    new.club_id, new.inviter_id, 'invite-' || new.id
  );
  return new;
end $$;
drop trigger if exists on_invite_created on public.club_invites;
create trigger on_invite_created
  after insert on public.club_invites
  for each row execute function public.notif_on_invite();

-- 2) Invito accettato (chi l'aveva mandato viene avvisato)
create or replace function public.notif_on_invite_accepted() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; who text;
begin
  if new.status = 'accepted' and coalesce(old.status,'') <> 'accepted' then
    select name into cname from public.clubs where id = new.club_id;
    select coalesce(username, name, 'Un lettore') into who from public.profiles where id = new.invitee_id;
    perform public.notify(
      new.inviter_id, 'invite_accepted',
      'Invito accettato',
      who || ' è entrato in «' || coalesce(cname,'un club') || '».',
      new.club_id, new.invitee_id, 'invacc-' || new.id
    );
  end if;
  return new;
end $$;
drop trigger if exists on_invite_accepted on public.club_invites;
create trigger on_invite_accepted
  after update on public.club_invites
  for each row execute function public.notif_on_invite_accepted();

-- 3) Nuovo follower
create or replace function public.notif_on_follow() returns trigger
language plpgsql security definer set search_path = public as $$
declare who text;
begin
  select coalesce(username, name, 'Un lettore') into who from public.profiles where id = new.follower_id;
  perform public.notify(
    new.followed_id, 'follower',
    'Nuovo follower',
    who || ' ha iniziato a seguirti.',
    null, new.follower_id, 'follow-' || new.follower_id || '-' || new.followed_id
  );
  return new;
end $$;
drop trigger if exists on_new_follow on public.follows;
create trigger on_new_follow
  after insert on public.follows
  for each row execute function public.notif_on_follow();

-- 4) Libro del mese scelto (tutti i membri tranne chi l'ha scelto)
create or replace function public.notif_on_book_chosen() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; m record;
begin
  if new.current_title is distinct from old.current_title and new.current_title is not null then
    select name into cname from public.clubs where id = new.id;
    for m in select user_id from public.club_members where club_id = new.id loop
      perform public.notify(
        m.user_id, 'book',
        'Nuovo libro del mese',
        'In «' || coalesce(cname,'un club') || '»: «' || new.current_title || '».',
        new.id, auth.uid(),
        'book-' || new.id || '-' || md5(new.current_title)
      );
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists on_book_chosen_notif on public.clubs;
create trigger on_book_chosen_notif
  after update on public.clubs
  for each row execute function public.notif_on_book_chosen();

-- 5) Nuova nota nel diario condiviso (agli altri membri del club)
create or replace function public.notif_on_note() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; who text; m record;
begin
  if coalesce(new.shared, false) then
    select name into cname from public.clubs where id = new.club_id;
    select coalesce(username, name, 'Un lettore') into who from public.profiles where id = new.user_id;
    for m in select user_id from public.club_members where club_id = new.club_id and user_id <> new.user_id loop
      perform public.notify(
        m.user_id, 'note',
        'Nuova nota nel diario',
        who || ' ha commentato «' || coalesce(new.book_title,'il libro') || '».',
        new.club_id, new.user_id, 'note-' || new.id || '-' || m.user_id
      );
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists on_note_shared on public.notes;
create trigger on_note_shared
  after insert on public.notes
  for each row execute function public.notif_on_note();
