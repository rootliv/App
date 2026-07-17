-- ============================================================================
-- Sblocca due delle notifiche finora "Presto disponibile": "Nuovo libro scelto"
-- e "Nuova nota disponibile". Stesso schema già usato per gli inviti ai club
-- (migration 20260715_push_notifications.sql): un trigger chiama la Edge
-- Function send-push via pg_net.
--
-- Aggiunge anche le colonne notif_libro/notif_nota su profiles: senza queste,
-- il toggle nell'app sarebbe un controllo finto (identico al problema appena
-- risolto per "Curiosità settimanale") perché il trigger non avrebbe modo di
-- sapere se un membro ha spento quella preferenza. Il client (index.html,
-- toggleNotifPref) le tiene aggiornate ogni volta che l'utente cambia il
-- toggle.
--
-- IMPORTANTE: prima di lanciare questo blocco, sostituisci in ENTRAMBE le
-- funzioni sotto INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY con la tua vera
-- service_role key (Dashboard -> Project Settings -> API -> service_role
-- secret). Mai nel codice del sito, solo qui, lato database.
--
-- Sicura da rilanciare più volte (idempotente).
-- ============================================================================

alter table public.profiles add column if not exists notif_libro boolean not null default true;
alter table public.profiles add column if not exists notif_nota  boolean not null default true;

-- ----------------------------------------------------------------------------
-- 1) NUOVO LIBRO SCELTO: quando cambia il libro corrente di un club (fine
--    sorteggio/votazione, o scelta diretta dell'admin), avvisa tutti i membri
--    tranne chi ha appena fatto la scelta.
-- ----------------------------------------------------------------------------
create or replace function public.notify_new_book_chosen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if new.current_title is distinct from old.current_title and new.current_title is not null then
    for r in
      select cm.user_id
      from public.club_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.club_id = new.id
        and cm.user_id <> auth.uid()
        and coalesce(p.notif_libro, true) = true
    loop
      perform net.http_post(
        url := 'https://ogcgfemadhtzzhdjkjda.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY'
        ),
        body := jsonb_build_object(
          'user_id', r.user_id,
          'title', 'Nuovo libro scelto',
          'body', 'Il club ha scelto: «' || new.current_title
                  || case when new.current_author is not null then '» di ' || new.current_author else '»' end
        )
      );
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists on_club_book_chosen on public.clubs;
create trigger on_club_book_chosen
  after update on public.clubs
  for each row
  execute function public.notify_new_book_chosen();

-- ----------------------------------------------------------------------------
-- 2) NUOVA NOTA DISPONIBILE: quando qualcuno scrive una nota nel diario
--    condiviso, avvisa solo i membri del club che, per posizione di lettura,
--    possono già vederla davvero (stessa regola anti-spoiler della RLS
--    notes_select_antispoiler: posizione nota <= posizione di lettura del
--    destinatario). Chi è più indietro nella lettura non viene avvisato ora:
--    lo scoprirà quando arriverà a quel punto del libro, che è corretto.
-- ----------------------------------------------------------------------------
create or replace function public.notify_new_note()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select cm.user_id
    from public.club_members cm
    join public.profiles p on p.id = cm.user_id
    where cm.club_id = new.club_id
      and cm.user_id <> new.user_id
      and coalesce(p.notif_nota, true) = true
      and new.position <= coalesce(
        (select rp.position from public.reading_progress rp
          where rp.user_id = cm.user_id and rp.club_id = new.club_id and rp.book_title = new.book_title),
        1)
  loop
    perform net.http_post(
      url := 'https://ogcgfemadhtzzhdjkjda.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'user_id', r.user_id,
        'title', 'Nuova nota nel diario condiviso',
        'body', 'È stata aggiunta una nuova nota su «' || new.book_title || '».'
      )
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists on_note_created on public.notes;
create trigger on_note_created
  after insert on public.notes
  for each row
  execute function public.notify_new_note();
