# MANUAL_TEST_CHECKLIST — Pàgina

Da eseguire da Alice sul telefono dopo ogni rilascio importante (in particolare dopo
aver lanciato `20260712_security_phase1.sql`, che cambia il comportamento della
ricerca persone e del login per username).

Per ognuna: passaggi, risultato atteso, dati necessari. Nessuna di queste è stata
eseguita da me — richiedono un account reale e l'app sul telefono.

## Autenticazione
- [ ] Login con email + password → entra normalmente.
- [ ] Login con username + password → entra normalmente (verifica dopo aver lanciato
      la migration 6: la funzione `email_for_login` è cambiata).
- [ ] Login con username sbagliato → messaggio generico "Credenziali non valide", non
      distingue più "username non trovato" da "password sbagliata".
- [ ] Registrazione con username già esistente → blocca con messaggio chiaro.
- [ ] Reset password via email → arriva la mail, il link funziona.

## Ricerca persone (sezione Lettori)
- [ ] Cercare un lettore per username → lo trova, mostra nome/avatar, nessuna email visibile.
- [ ] **Verifica che cercare per email non funzioni più** (rimosso volutamente per
      privacy): digitando un indirizzo email nella ricerca non deve comparire nessuno
      per quel motivo (a meno che l'email coincida per caso con lo username di qualcuno).

## Club
- [ ] Vedere i membri di un club a cui appartieni → nomi e avatar corretti.
- [ ] Invitare qualcuno per username → funziona, l'invitato riceve la notifica.
- [ ] Scegliere un libro già letto da un membro del club → blocca con l'avviso corretto.

## Home
- [ ] "Continua a leggere" mostra il libro giusto con pagina/percentuale corretta.
- [ ] Obiettivo annuale coerente con i libri completati nell'anno corrente.
- [ ] Nessuna card vuota se non ci sono dati (deve mostrare il messaggio "nessun libro…").

## Profilo
- [ ] Pagine lette mostrate con il punto delle migliaia (es. "2.280", non "2280").
- [ ] Generi con "Senza genere" se ci sono libri non classificati, percentuali coerenti.
- [ ] Pulsante "Scegli autori"/"Modifica generi" completamente visibile, non coperto dalla
      barra di navigazione in basso.

## Libreria
- [ ] Ricerca (compare da 6+ libri) filtra per titolo/autore/genere mentre scrivi.
- [ ] Aggiungere un libro: i tre pulsanti (da leggere / sto leggendo / già letto)
      funzionano tutti.

## PWA / offline
- [ ] Installare l'app dalla home del telefono → si apre a schermo intero, senza barra
      del browser.
- [ ] Aprire l'app senza connessione dopo averla già usata online almeno una volta →
      deve mostrare l'interfaccia con gli stili (verifica dell'estrazione di
      `styles.css`: se manca lo stile, l'estrazione ha un problema di cache offline).
- [ ] Chiudere e riaprire l'app dopo un aggiornamento (build v112+) → deve mostrare la
      versione nuova, non quella vecchia in cache (verifica del numero di build in
      basso a sinistra nella console browser, se accessibile, o dal comportamento
      visibile delle funzioni nuove).

## Accessibilità (verifica visiva, non automatica)
- [ ] Ingrandire il testo nelle impostazioni di accessibilità del telefono → l'app resta
      leggibile, nessun testo tagliato in modo illeggibile.
- [ ] Tutti i pulsanti principali sono comodi da toccare con il pollice (nessuno troppo
      piccolo o troppo vicino a un altro).

## Rischio in caso di fallimento

Se un punto di questa checklist fallisce dopo aver lanciato la migration 6, il problema
più probabile è che la funzione `public_profiles` o `is_username_taken` non esiste ancora
sul database (migration non lanciata o lanciata parzialmente). Prima di chiedere una
correzione, verificare nel SQL Editor con:

```sql
select * from public.public_profiles limit 1;
select public.is_username_taken('test_username_che_non_esiste');
```

Se danno errore "relation/function does not exist", la migration 6 non è stata applicata.
