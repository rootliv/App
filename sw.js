/* Service worker di Pàgina — strategia NETWORK-FIRST.
   Scopo principale: rendere l'app installabile come PWA (icona sulla home, apertura
   standalone). La cache è usata SOLO come ripiego offline: ogni richiesta prova prima
   la rete, così l'utente riceve sempre la versione più aggiornata del sito (coerente
   con i meta anti-cache già presenti in index.html).
   Nota: la cache viene svuotata e rinominata ad ogni cambio di CACHE_VERSION. */

const CACHE_VERSION = 'pagina-v3';
const OFFLINE_URLS = ['./', './index.html', './manifest.json', './icons/icon-192.png', './icons/icon-512.png'];

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

  event.respondWith(
    fetch(req)
      .then((res) => {
        // aggiorna la copia offline in background
        const copy = res.clone();
        caches.open(CACHE_VERSION).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match('./index.html')))
  );
});
