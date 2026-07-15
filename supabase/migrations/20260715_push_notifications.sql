-- Notifiche push (Android): tabella dei token dei dispositivi + invio automatico
-- quando arriva un nuovo invito a un club.
--
-- Il client (scripts/native.js) gia' salva qui il token del dispositivo dopo aver
-- ottenuto il permesso di notifiche: nessuna modifica lato app necessaria, la tabella
-- deve solo esistere con questo nome/colonne.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android','ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(token)
);

create index if not exists device_tokens_user_id_idx on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

drop policy if exists "device_tokens: leggi il tuo" on public.device_tokens;
create policy "device_tokens: leggi il tuo" on public.device_tokens
  for select using (auth.uid() = user_id);

drop policy if exists "device_tokens: crea il tuo" on public.device_tokens;
create policy "device_tokens: crea il tuo" on public.device_tokens
  for insert with check (auth.uid() = user_id);

drop policy if exists "device_tokens: aggiorna il tuo" on public.device_tokens;
create policy "device_tokens: aggiorna il tuo" on public.device_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "device_tokens: elimina il tuo" on public.device_tokens;
create policy "device_tokens: elimina il tuo" on public.device_tokens
  for delete using (auth.uid() = user_id);

-- pg_net: permette a un trigger Postgres di fare una chiamata HTTP in background
-- (non blocca ne' rallenta l'inserimento dell'invito se la chiamata e' lenta o fallisce).
create extension if not exists pg_net with schema extensions;

-- IMPORTANTE: prima di lanciare questo blocco, sostituisci
-- INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY con la tua vera service_role key
-- (Dashboard -> Project Settings -> API -> service_role secret). Non e' la stessa
-- chiave "anon/publishable" usata nel sito: questa non va MAI messa nel codice
-- del sito, solo qui nel database, lato server.
create or replace function public.notify_new_club_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending' then
    perform net.http_post(
      url := 'https://ogcgfemadhtzzhdjkjda.supabase.co/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer INCOLLA_QUI_LA_TUA_SERVICE_ROLE_KEY'
      ),
      body := jsonb_build_object(
        'user_id', new.invitee_id,
        'title', 'Nuovo invito a un club',
        'body', 'Hai ricevuto un invito a unirti a un club su Pagina.'
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists on_club_invite_created on public.club_invites;
create trigger on_club_invite_created
  after insert on public.club_invites
  for each row
  execute function public.notify_new_club_invite();
