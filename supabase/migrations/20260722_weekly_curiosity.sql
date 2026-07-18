-- ============================================================================
-- "Curiosità della settimana" come vera rubrica editoriale, indipendente
-- dall'Assistente AI e dal campo book.cur (che resta intatto, invariato,
-- usato solo nella scheda libro e come ultimo fallback in caso di errore).
--
-- Una riga per (utente, settimana): la generazione avviene lato client alla
-- prima apertura della Home della settimana, ma viene sempre SALVATA qui,
-- così la stessa curiosità è visibile su tutti i dispositivi dell'utente e
-- non viene mai rigenerata più di una volta a settimana.
--
-- Concorrenza tra dispositivi: il vincolo unique(user_id, week_key) impedisce
-- a due dispositivi di creare due righe diverse per la stessa settimana. Il
-- client fa un upsert "ON CONFLICT DO NOTHING" e poi rilegge SEMPRE la riga
-- definitiva: chi arriva secondo non sovrascrive, semplicemente si allinea
-- a quello che ha già vinto la corsa.
--
-- PASSI MANUALI DOPO AVER APPLICATO QUESTA MIGRATION: nessuno, si attiva da
-- sola. Le chiavi AI restano solo nella Edge Function "curiosita" (già
-- esistente): il client non chiama mai provider AI direttamente.
-- ============================================================================

create table if not exists public.weekly_curiosities (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  week_key      text not null,                    -- es. '2026-W29' (ISO week)
  book_id       bigint,                            -- id in public.books, se disponibile (nessuna FK: il tipo esatto
                                                     -- della colonna id di books non è fissato da una migration in
                                                     -- questo repo; se vuoi puoi aggiungerla tu a mano più avanti)
  book_title    text,
  book_author   text,
  category      text not null,
  title         text not null,
  teaser        text not null,
  content       text not null,
  source_name   text,                              -- es. 'Wikidata', 'Wikipedia', 'Pàgina', 'AI'
  source_url    text,                              -- link preciso alla fonte, quando esiste
  spoiler_level text not null default 'none' check (spoiler_level in ('none','light')),
  saved         boolean not null default false,
  seen_at       timestamptz,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  unique (user_id, week_key)
);

create index if not exists weekly_curiosities_user_week_idx
  on public.weekly_curiosities (user_id, week_key desc);

alter table public.weekly_curiosities enable row level security;

-- Ognuno vede e gestisce solo le proprie curiosità.
drop policy if exists wc_select_own on public.weekly_curiosities;
create policy wc_select_own on public.weekly_curiosities
  for select using (auth.uid() = user_id);

drop policy if exists wc_insert_own on public.weekly_curiosities;
create policy wc_insert_own on public.weekly_curiosities
  for insert with check (auth.uid() = user_id);

-- UPDATE serve per "Salva" (saved) e per segnare seen_at quando l'utente apre
-- il dettaglio: sempre e solo sulla propria riga.
drop policy if exists wc_update_own on public.weekly_curiosities;
create policy wc_update_own on public.weekly_curiosities
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Nessuna policy di delete: le curiosità passate restano come storico, usato
-- anche per l'anti-ripetizione (non riproporre libro/categoria delle ultime
-- settimane).
