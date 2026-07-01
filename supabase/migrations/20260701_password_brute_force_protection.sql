-- ============================================================================
-- Protezione anti brute-force sul login con password (Supabase Auth Hook).
--
-- Questo NON è un controllo lato client: è una funzione Postgres che Supabase
-- Auth esegue lato server ad ogni verifica di password (login), quindi non è
-- bypassabile chiamando l'API di autenticazione direttamente.
--
-- Blocca temporaneamente un account dopo troppi tentativi di password errati
-- consecutivi, con un tempo di attesa che cresce ("exponential backoff"):
--   5 tentativi falliti  -> attesa 30 secondi
--   8 tentativi falliti  -> attesa 5 minuti
--   12+ tentativi falliti -> attesa 30 minuti
-- Un login riuscito azzera il contatore.
--
-- ATTENZIONE - passo manuale richiesto dopo aver applicato questa migration:
--   Vai su Supabase Dashboard → Authentication → Hooks → "Password Verification
--   Hook" e seleziona la funzione public.hook_password_verification_attempt.
--   Il codice da solo (la funzione SQL) non abilita l'hook: va collegato dalla
--   Dashboard (o via supabase CLI / Management API) perché tocca la
--   configurazione del progetto Auth, non un oggetto nel database.
-- ============================================================================

create table if not exists public.password_verification_attempts (
  user_id uuid primary key,
  failed_count int not null default 0,
  last_failed_at timestamptz,
  locked_until timestamptz
);

-- Solo il ruolo usato da Supabase Auth per chiamare l'hook può leggere/scrivere
-- questa tabella: non deve essere raggiungibile dalle API pubbliche (anon/authenticated).
grant select, insert, update on table public.password_verification_attempts to supabase_auth_admin;
revoke all on table public.password_verification_attempts from authenticated, anon, public;

create or replace function public.hook_password_verification_attempt(event jsonb)
returns jsonb
language plpgsql
as $$
declare
  v_user_id uuid := (event->>'user_id')::uuid;
  v_valid boolean := (event->>'valid')::boolean;
  v_row public.password_verification_attempts;
  v_wait interval;
begin
  select * into v_row from public.password_verification_attempts where user_id = v_user_id;

  -- Se l'account è attualmente bloccato, rifiuta indipendentemente dal risultato
  -- della verifica della password (anche se corretta), finché non scade il blocco.
  if v_row.locked_until is not null and v_row.locked_until > now() then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Troppi tentativi falliti. Riprova più tardi.',
      'should_logout_user', false
    );
  end if;

  if v_valid then
    -- Password corretta: azzera il contatore dei tentativi falliti.
    update public.password_verification_attempts
      set failed_count = 0, locked_until = null
      where user_id = v_user_id;
    return jsonb_build_object('decision', 'continue');
  end if;

  -- Password errata: incrementa il contatore e valuta se applicare un blocco.
  insert into public.password_verification_attempts (user_id, failed_count, last_failed_at)
    values (v_user_id, 1, now())
  on conflict (user_id) do update
    set failed_count = public.password_verification_attempts.failed_count + 1,
        last_failed_at = now()
    returning * into v_row;

  v_wait := case
    when v_row.failed_count >= 12 then interval '30 minutes'
    when v_row.failed_count >= 8  then interval '5 minutes'
    when v_row.failed_count >= 5  then interval '30 seconds'
    else null
  end;

  if v_wait is not null then
    update public.password_verification_attempts
      set locked_until = now() + v_wait
      where user_id = v_user_id;
  end if;

  -- Lascia comunque che Supabase Auth applichi il suo comportamento standard
  -- per un tentativo fallito (risposta generica "credenziali non valide").
  return jsonb_build_object('decision', 'continue');
end;
$$;
