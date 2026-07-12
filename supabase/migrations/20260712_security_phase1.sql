-- ============================================================================
-- FASE 1 SICUREZZA — profili pubblici/privati, login per username con
-- rate limiting persistente, controllo membership su club_member_read_book.
--
-- Sicura da rilanciare più volte (idempotente): usa "if exists"/"or replace"
-- ovunque possibile.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) PROFILI: solo il proprietario legge la propria riga completa (incluse
--    colonne sensibili come email). Prima, chiunque autenticato poteva
--    leggere TUTTE le colonne di TUTTI i profili, email compresa.
-- ----------------------------------------------------------------------------
drop policy if exists profiles_search_read on public.profiles;
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select using (auth.uid() = id);

-- Vista pubblica: SOLO le colonne non sensibili, per TUTTI i profili.
-- È una vista "normale" (non RLS-limitata riga per riga) perché il suo scopo
-- è proprio essere consultabile da chiunque sia loggato — la sicurezza qui
-- sta nel fatto che la lista di colonne selezionate NON include mai email
-- né altri dati privati: sono strutturalmente assenti dall'output, non
-- filtrati a runtime.
create or replace view public.public_profiles as
  select
    id,
    username,
    name,
    (data->>'avatar') as avatar,
    coalesce(public_library, false) as public_library,
    created_at
  from public.profiles;

grant select on public.public_profiles to authenticated;
revoke all on public.public_profiles from anon, public;

-- ----------------------------------------------------------------------------
-- 2) LOGIN CON USERNAME: la funzione che risolve username -> email deve
--    restare (Supabase Auth richiede l'email per signInWithPassword: non è
--    aggirabile senza un servizio server-side dedicato, che qui non esiste),
--    MA va protetta con un limite persistente ai tentativi, altrimenti è un
--    oracolo per raccogliere in massa email valide provando molti username.
-- ----------------------------------------------------------------------------
create table if not exists public.username_lookup_attempts (
  username_key text primary key,   -- username normalizzato (lowercase, trim)
  attempts int not null default 0,
  window_start timestamptz not null default now(),
  locked_until timestamptz
);
-- Solo la funzione (SECURITY DEFINER) tocca questa tabella: nessun accesso diretto.
revoke all on table public.username_lookup_attempts from authenticated, anon, public;

create or replace function public.email_for_login(login text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(trim(login));
  v_row public.username_lookup_attempts;
  v_email text;
begin
  if v_key is null or v_key = '' then
    return null;
  end if;

  select * into v_row from public.username_lookup_attempts where username_key = v_key;

  -- Bloccato: rifiuta indipendentemente dal fatto che l'username esista o meno,
  -- così il tempo di risposta e l'esito non rivelano nulla in più.
  if v_row.locked_until is not null and v_row.locked_until > now() then
    return null;
  end if;

  -- Finestra scaduta (10 minuti): riparte da zero.
  if v_row is null or v_row.window_start < now() - interval '10 minutes' then
    insert into public.username_lookup_attempts(username_key, attempts, window_start, locked_until)
      values (v_key, 1, now(), null)
      on conflict (username_key) do update
        set attempts = 1, window_start = now(), locked_until = null;
  else
    update public.username_lookup_attempts
      set attempts = attempts + 1,
          locked_until = case when attempts + 1 >= 8 then now() + interval '15 minutes' else null end
      where username_key = v_key;
  end if;

  -- Se questo tentativo ha appena fatto scattare il blocco, non rispondere.
  select * into v_row from public.username_lookup_attempts where username_key = v_key;
  if v_row.locked_until is not null and v_row.locked_until > now() then
    return null;
  end if;

  select au.email into v_email
    from public.profiles p
    join auth.users au on au.id = p.id
    where lower(p.username) = v_key
    limit 1;

  return v_email; -- torna al client solo per il tentativo di login immediato,
                   -- mai mostrato né salvato lato client.
end;
$$;

revoke all on function public.email_for_login(text) from public;
grant execute on function public.email_for_login(text) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3) club_member_read_book: prima chiunque autenticato poteva interrogare
--    QUALSIASI club (anche di cui non faceva parte) e scoprire chi ha letto
--    cosa. Ora verifica che chi chiama sia davvero membro di quel club.
-- ----------------------------------------------------------------------------
create or replace function public.club_member_read_book(p_club_id bigint, p_title text)
returns table(reader_name text)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Chi chiama deve essere membro del club indicato, altrimenti nessun risultato.
  if not exists (
    select 1 from public.club_members
    where club_id = p_club_id and user_id = auth.uid()
  ) then
    return;
  end if;

  return query
    select coalesce(pr.name, pr.username, 'un membro') as reader_name
    from public.club_members m
    join public.books b on b.user_id = m.user_id
    left join public.profiles pr on pr.id = m.user_id
    where m.club_id = p_club_id
      and b.status = 'read'
      and lower(trim(b.title)) = lower(trim(p_title))
    limit 1;
end;
$$;

revoke all on function public.club_member_read_book(bigint, text) from public, anon;
grant execute on function public.club_member_read_book(bigint, text) to authenticated;

-- ----------------------------------------------------------------------------
-- 4) Controllo "username già preso": serve anche PRIMA del login (in fase di
--    registrazione, quando non c'è ancora una sessione) e nel profilo. Con le
--    righe altrui non più leggibili direttamente, questa piccola funzione
--    restituisce solo un booleano — nessun altro dato sulle righe altrui.
-- ----------------------------------------------------------------------------
create or replace function public.is_username_taken(p_username text, p_exclude_id uuid default null)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(
    select 1 from public.profiles
    where lower(username) = lower(trim(p_username))
      and (p_exclude_id is null or id <> p_exclude_id)
  );
$$;

revoke all on function public.is_username_taken(text, uuid) from public;
grant execute on function public.is_username_taken(text, uuid) to anon, authenticated;
