# Supabase — Passo per il Profilo (sezione "Tu" azzerata)

Ho reso la sezione **Tu** completamente reale e **vuota per default** per ogni nuovo utente. Serve **un ultimo SQL** (una colonna per salvare i dati del profilo).

## 1. Esegui questo SQL
Su Supabase: **SQL Editor → New query** → incolla → **Run**:

```sql
alter table profiles add column if not exists data jsonb default '{}'::jsonb;
```

"Success. No rows returned" = fatto. ✅

## 2. Pulisci il vecchio account di test (importante)
Il tuo **primo account di prova** era stato creato quando l'app inseriva ancora 6 libri demo: quei libri sono rimasti nel database di quell'account. Due opzioni:

- **Consigliata:** registra un **nuovo account** per verificare l'azzeramento. Vedrai libreria, profilo, mappa, ecc. completamente vuoti.
- Oppure svuota il vecchio account: nell'app apri ogni libro demo → **🗑 Rimuovi**. (In alternativa, su Supabase: **Table Editor → books → seleziona le righe → Delete**.)

## Cosa è cambiato (cosa controllare)

**La sezione "Tu" ora parte azzerata:**
- **Profilo**: nome e username sono i tuoi; generi, autori, libri del cuore, "non graditi", ritmo e obiettivo sono **vuoti**, con messaggi tipo "Non hai ancora indicato…". Pulsante **✏️ Modifica profilo** per compilarli (si salvano nel tuo account).
- **Libreria**: vuota, con invito ad aggiungere il primo libro. Niente più libri demo.
- **Home**: statistiche a 0, "Continua a leggere" compare solo se hai libri, "Ti aspettano" mostra solo cose reali dei tuoi club.

**Niente più dati demo per gli account veri** anche in:
- **Mappa** (solo i tuoi libri; nessun "viaggio del club" finto),
- **Assistente AI** (ti saluta col tuo nome; la parte "per il club" appare solo se hai un club),
- **Calendario** e **Notifiche** (stati vuoti gestiti).

> La **modalità Demo** ("Entra nella demo") resta volutamente piena di contenuti d'esempio: serve a mostrare l'app senza registrarsi. Gli account veri partono puliti.

## Ottimizzazione mobile (fatta)
- Niente scorrimento orizzontale indesiderato.
- Campi di testo a 16px su telefono → **niente zoom automatico** su iPhone quando tocchi un campo.
- Spaziature, mappa e finestre adattate agli schermi piccoli; griglia libri a 2 colonne sui telefoni stretti; pulsanti più comodi da toccare.

## Per vedere tutto online
Ricordati di **pubblicare la nuova versione** (GitHub Desktop → Commit → Push, vedi `Guida-Pubblicazione.md`). Poi prova su https://rootliv.github.io/App/ registrando un nuovo account.

Se trovi un messaggio d'errore, copiamelo esatto e lo sistemo.
