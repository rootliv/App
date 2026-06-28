# Supabase — Passo per i Club condivisi

Ho aggiunto i **club del libro reali e condivisi**. Manca **un ultimo SQL da incollare** una volta, per abilitare il "libro del mese" del club.

## Cosa fare

1. Su Supabase: **SQL Editor** → **New query**.
2. Incolla questo blocco e premi **Run**:

```sql
-- Colonne per il libro del mese del club
alter table clubs add column if not exists current_title text;
alter table clubs add column if not exists current_author text;
alter table clubs add column if not exists current_cover text;

-- Permetti a chi ha creato il club (admin) di aggiornare il libro del mese
drop policy if exists "club: aggiorna chi e owner" on clubs;
create policy "club: aggiorna chi e owner" on clubs
  for update using (owner = auth.uid()) with check (owner = auth.uid());
```

3. Se vedi **"Success. No rows returned"** è tutto a posto. ✅

## Come provare i club (anche con un amico)

1. Accedi con il tuo account. Vai su **Club del libro** → **Crea o unisciti** → **Crea club** (nome, emoji, descrizione).
2. Come admin, clicca **Scegli il libro del mese** e cercane uno.
3. Copia il **Codice invito** mostrato nel club.
4. Da un **altro account** (anche un secondo browser, o un amico): **Club → Unisciti con un codice** → incolla il codice. Comparirà tra i membri.
5. Quando il club ha un libro, apri **Diario condiviso**: scrivi una nota indicando il tuo avanzamento (%). Gli altri la vedranno **solo quando raggiungono quel punto** — niente spoiler.

## Cosa è reale adesso
- **Club**: creazione, adesione via codice, elenco, ruoli (admin/membro), membri reali dal database.
- **Libro del mese**: scelto dall'admin, visibile a tutti i membri.
- **Diario condiviso**: note salvate nel cloud, con regola anti-spoiler basata sull'avanzamento.

## Cosa resta da fare (prossimi step)
- **Votazione** per scegliere il libro a turno, e **incontri** del club nel cloud.
- Collegare anche **Home**, **Mappa** e **Notifiche** ai dati reali (ora mostrano contenuti di esempio).

Se qualcosa non funziona, dimmi il messaggio d'errore esatto (rosso) e lo sistemo.
