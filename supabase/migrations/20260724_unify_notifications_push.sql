-- ============================================================================
-- NOTIFICHE UNIFICATE: una sola fonte di verità per l'app E per le push
--
-- PERCHÉ
-- Finora esistevano DUE sistemi paralleli e scollegati:
--  1) la tabella `notifications` + i trigger che la riempiono (quello che vedi
--     nell'app, ad app aperta) — copre inviti, follower, libro scelto, nota;
--  2) trigger SEPARATI che mandano la push (ad app chiusa) — ma coprivano SOLO
--     gli inviti, il libro scelto e le note. I follower non generavano MAI una
--     push, a prescindere da tutto.
-- Risultato: "le notifiche non funzionano bene ad app chiusa" — perché in
-- pratica ne mancava un pezzo, ed erano due sistemi da tenere allineati a mano.
--
-- COSA FA QUESTA MIGRATION
-- Rende `notify()` (la funzione unica già chiamata da OGNI trigger di notifica)
-- responsabile di ENTRAMBE le cose: scrive la riga in `notifications` (per l'app)
-- E, se l'inserimento è andato a buon fine (non era un doppione), manda anche la
-- push. Un solo punto, una sola volta, per qualunque tipo di evento — inclusi i
-- follower, che prima non la mandavano mai.
--
-- Toglie anche una fonte di doppioni: i VECCHI trigger dedicati alla sola push
-- (per inviti, libro, nota) vengono disattivati, perché ora la push parte già
-- da `notify()`. Senza questo passo, chi ha le notifiche attive riceverebbe la
-- STESSA push due volte.
--
-- Preserva una regola importante che il vecchio trigger delle note aveva e che
-- il nuovo sistema in-app non applicava ancora: non avvisare (né in app né via
-- push) chi non ha ancora raggiunto, nella lettura, il punto a cui si riferisce
-- la nota — niente notifiche che anticipano contenuti non ancora sbloccati.
--
-- IMPORTANTE: sostituisci INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY (compare una sola
-- volta qui sotto, dentro notify()) con la tua vera service_role key prima di
-- lanciare — stessa chiave già usata per le altre migration delle push.
--
-- Sicura da rilanciare più volte (idempotente).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) notify(): ora scrive la notifica E manda la push, in un solo posto.
-- ----------------------------------------------------------------------------
create or replace function public.notify(
  p_user uuid, p_kind text, p_title text, p_body text default '',
  p_club bigint default null, p_actor uuid default null, p_dedup text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean;
begin
  if p_user is null or (p_actor is not null and p_actor = p_user) then
    return; -- non notificare l'autore del proprio stesso evento
  end if;

  insert into public.notifications(user_id, kind, title, body, club_id, actor_id, dedup_key)
  values (p_user, p_kind, p_title, coalesce(p_body,''), p_club, p_actor, p_dedup)
  on conflict do nothing
  returning true into v_inserted;

  if v_inserted is not true then
    return; -- stesso evento già notificato prima: niente riga doppia, niente push doppia
  end if;

  -- Push (Android, via Firebase Cloud Messaging): se il destinatario non ha l'app
  -- installata (nessun token in device_tokens) o Firebase non è ancora configurato,
  -- send-push risponde "ok" senza inviare nulla — non blocchiamo mai l'evento per questo.
  begin
    perform net.http_post(
      url := 'https://ogcgfemadhtzzhdjkjda.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', coalesce(p_body,''))
    );
  exception when others then
    null; -- la push è un "di più": se fallisce, la notifica in-app resta comunque salvata
  end;
end;
$$;

-- ----------------------------------------------------------------------------
-- 2) "Nuovo libro scelto": ora rispetta anche qui la preferenza notif_libro
--    (prima la rispettava solo la vecchia push, mai la versione in-app).
-- ----------------------------------------------------------------------------
create or replace function public.notif_on_book_chosen() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; m record;
begin
  if new.current_title is distinct from old.current_title and new.current_title is not null then
    select name into cname from public.clubs where id = new.id;
    for m in
      select cm.user_id from public.club_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.club_id = new.id and coalesce(p.notif_libro, true) = true
    loop
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

-- ----------------------------------------------------------------------------
-- 3) "Nuova nota nel diario": ora rispetta anche notif_nota E la regola
--    anti-spoiler (non avvisare chi non ha ancora raggiunto quella pagina).
-- ----------------------------------------------------------------------------
create or replace function public.notif_on_note() returns trigger
language plpgsql security definer set search_path = public as $$
declare cname text; who text; m record;
begin
  if coalesce(new.shared, false) then
    select name into cname from public.clubs where id = new.club_id;
    select coalesce(username, name, 'Un lettore') into who from public.profiles where id = new.user_id;
    for m in
      select cm.user_id from public.club_members cm
      join public.profiles p on p.id = cm.user_id
      where cm.club_id = new.club_id
        and cm.user_id <> new.user_id
        and coalesce(p.notif_nota, true) = true
        and new.position <= coalesce(
          (select rp.position from public.reading_progress rp
            where rp.user_id = cm.user_id and rp.club_id = new.club_id and rp.book_title = new.book_title),
          1)
    loop
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

-- ----------------------------------------------------------------------------
-- 4) Disattiva i vecchi trigger dedicati SOLO alla push: ora ridondanti, e
--    causerebbero una doppia push per lo stesso evento.
-- ----------------------------------------------------------------------------
drop trigger if exists on_club_invite_created on public.club_invites;
drop trigger if exists on_club_book_chosen on public.clubs;
drop trigger if exists on_note_created on public.notes;
