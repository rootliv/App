# Supabase — Passo per gli Incontri del club

Ho collegato al cloud la **Home**, gli **Incontri** e le **Notifiche** (ora reali, non più dati di esempio, quando sei loggata con l'account vero). Manca **un ultimo SQL** per la tabella degli incontri.

## Cosa fare

1. Su Supabase: **SQL Editor** → **New query**.
2. Incolla e premi **Run**:

```sql
create table if not exists meetings (
  id bigint generated always as identity primary key,
  club_id bigint references clubs on delete cascade,
  title text,
  date date,
  place text,
  link text,
  created_by uuid references auth.users on delete set null,
  created_at timestamptz default now()
);

alter table meetings enable row level security;

drop policy if exists "incontri: leggi" on meetings;
create policy "incontri: leggi" on meetings for select using (auth.role() = 'authenticated');

drop policy if exists "incontri: crea" on meetings;
create policy "incontri: crea" on meetings for insert with check (auth.role() = 'authenticated');

drop policy if exists "incontri: gestisci i tuoi" on meetings;
create policy "incontri: gestisci i tuoi" on meetings for all using (auth.uid() = created_by) with check (auth.uid() = created_by);
```

3. **"Success. No rows returned"** = fatto. ✅

## Cosa è diventato reale (con account vero)

- **Home**: saluto col tuo nome, libri letti/in lettura presi dalla tua libreria, numero di club, giorni al prossimo incontro, "Continua a leggere" e la sezione "Ti aspettano" (votazioni aperte, tocca a te scegliere, incontri vicini, diario).
- **Incontri**: nel club puoi creare un incontro (titolo, data, luogo, link videochiamata). Tutti i membri lo vedono. La pagina **Incontri** mostra i prossimi di tutti i tuoi club.
- **Notifiche**: generate dallo stato reale (votazione aperta, tuo turno di scelta, incontro imminente, diario).

## Prova
1. Aggiungi/segna un libro come "in lettura" → comparirà in Home.
2. In un club, crea un incontro con data futura → lo vedi in **Incontri** e in Home.
3. Avvia una votazione in un club → comparirà tra le **Notifiche** e in "Ti aspettano".

Se compare un errore, mandami il messaggio esatto e lo sistemo.
