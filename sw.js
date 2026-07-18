/* Service worker di Pàgina — strategia NETWORK-FIRST con bypass FORZATO della cache HTTP.
   Scopo principale: rendere l'app installabile come PWA (icona sulla home, apertura
   standalone). La Cache Storage (Cache API) è usata SOLO come ripiego offline.

   IMPORTANTE — lezione imparata: un semplice fetch(req) NON garantisce una richiesta di
   rete davvero fresca. Il browser (e in mezzo, a volte, la rete dati/il proxy del gestore
   telefonico) può comunque soddisfare quella fetch con una risposta HTTP già in cache,
   perché fetch() di per sé rispetta le regole di cache HTTP standard salvo indicazione
   contraria. I meta tag "Cache-Control"/"Pragma" in index.html NON bastano: i browser
   moderni li ignorano in gran parte per le pagine di navigazione — servirebbe un vero
   header HTTP dal server, cosa che GitHub Pages non permette di configurare. Per questo
   qui si forza esplicitamente {cache:'no-store'} su ogni richiesta di rete: bypassa
   qualunque cache HTTP intermedia (browser, rete mobile, CDN) e garantisce che l'utente
   riceva sempre l'ultima versione pubblicata.
   Nota: la Cache Storage viene svuotata e rinominata ad ogni cambio di CACHE_VERSION. */

const CACHE_VERSION = 'pagina-v91';
const OFFLINE_URLS = ['./', './index.html', './styles.css', './manifest.json', './icons/icon-192.png', './icons/icon-512.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((c) => c.addAll(OFFLINE_URLS)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  // Solo GET della stessa origine: API esterne (Supabase, Google Books, mappe…)
  // passano dritte alla rete senza toccare la cache.
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;

  // Richiesta "fresca" forzata: no-store ignora qualunque cache HTTP nel percorso.
  const freshReq = new Request(req.url, { cache: 'no-store', credentials: req.credentials, mode: 'same-origin' });

  event.respondWith(
    fetch(freshReq)
      .then((res) => {
        // aggiorna la copia offline in background
        const copy = res.clone();
        caches.open(CACHE_VERSION).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      // Offline: ignoreSearch così una richiesta versionata (es. styles.css?v=145)
      // trova comunque la copia salvata (./styles.css), senza restare senza stili.
      .catch(() => caches.match(req, { ignoreSearch: true }).then((hit) => hit || caches.match('./index.html')))
  );
});
