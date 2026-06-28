# Supabase — Passo extra (username e login)

Ho collegato l'app a Supabase. Manca **un solo passaggio da fare tu**, una volta: aggiungere lo **username** e le funzioni che permettono il login con username. È sempre copia-e-incolla.

## Cosa fare

1. Su Supabase, menu a sinistra → **SQL Editor** → **New query**.
2. Copia **tutto** il blocco qui sotto, incollalo e premi **Run**.

```sql
-- 1) Aggiungi lo username ai profili (unico, niente doppioni)
alter table profiles add column if not exists username text unique;

-- 2) Crea automaticamente il profilo (nome + username) a ogni registrazione
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, username)
  values (new.id, new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'username')
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3) Permetti il login con username: trova l'email corrispondente
create or replace function public.email_for_login(login text)
returns text language sql security definer set search_path = public, auth as $$
  select u.email::text
  from auth.users u
  left join public.profiles p on p.id = u.id
  where lower(u.email) = lower(login) or lower(p.username) = lower(login)
  limit 1;
$$;

grant execute on function public.email_for_login(text) to anon, authenticated;
```

3. Se vedi **"Success. No rows returned"**, è tutto a posto. ✅

## Controllo importante (registrazione immediata)

Perché la registrazione faccia entrare subito (senza dover confermare l'email a mano ogni volta), durante il test:

- Menu a sinistra → **Authentication** → **Sign In / Providers** → **Email**.
- Disattiva **"Confirm email"** → salva.

(Quando l'app sarà pubblica e usata da altri, conviene riattivarla.)

## Poi prova così

1. Apri l'app, clicca **Registrati**: inserisci nome, username, email e password.
2. Dovrebbe entrare subito. Valuta un libro o aggiungine uno.
3. Clicca **Esci** (icona in basso a sinistra) e poi **Accedi** usando **lo username** (o l'email): ritrovi la tua libreria.
4. Bonus: prova ad accedere con lo stesso account da un **altro dispositivo/browser** — i dati ci sono, perché ora sono nel cloud. ☁️

Se qualcosa non va, dimmi **esattamente** il messaggio che compare in rosso nella schermata di accesso: con quello capisco subito cosa sistemare.
