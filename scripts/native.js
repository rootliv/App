/* ============================================================
   native.js — Bridge tra l'app web Pàgina e Capacitor (iOS/Android)
   Caricato SOLO nella build nativa (iniettato da build-www.sh).
   Su web normale questo file non viene servito, quindi l'app resta
   invariata nel browser.
   ============================================================ */
(function () {
  'use strict';
  const Cap = window.Capacitor;
  if (!Cap || !Cap.isNativePlatform || !Cap.isNativePlatform()) {
    // Non siamo in app nativa: non fare nulla, l'app web funziona da sola.
    return;
  }
  const P = Cap.Plugins || {};
  const platform = Cap.getPlatform ? Cap.getPlatform() : 'web';
  document.documentElement.classList.add('native', 'native-' + platform);

  /* ---- 1. Splash screen: nascondi quando l'app è pronta ---- */
  function hideSplash() {
    try { P.SplashScreen && P.SplashScreen.hide(); } catch (e) {}
  }
  // nascondi dopo che il primo render è avvenuto
  window.addEventListener('load', () => setTimeout(hideSplash, 400));
  setTimeout(hideSplash, 2500); // fail-safe

  /* ---- 2. Status bar: testo chiaro su sfondo verde scuro ---- */
  try {
    if (P.StatusBar) {
      P.StatusBar.setStyle({ style: 'DARK' }); // icone chiare
      if (platform === 'android') {
        P.StatusBar.setBackgroundColor({ color: '#123829' });
        P.StatusBar.setOverlaysWebView({ overlay: false });
      }
    }
  } catch (e) {}

  /* ---- 3. Tasto indietro Android: chiudi modali/sidebar prima di uscire ---- */
  try {
    if (P.App) {
      P.App.addListener('backButton', ({ canGoBack }) => {
        // Se c'è un overlay/modale aperto, chiudilo
        const overlay = document.getElementById('overlay');
        if (overlay && overlay.classList.contains('open')) {
          try { window.closeModal && window.closeModal(); } catch (e) {}
          return;
        }
        const sidebar = document.getElementById('sidebar');
        if (sidebar && sidebar.classList.contains('show')) {
          sidebar.classList.remove('show');
          document.body.classList.remove('sidebar-open');
          return;
        }
        // Se non siamo in Home, torna in Home invece di uscire
        try {
          if (window.current && window.current !== 'home' && typeof window.go === 'function') {
            window.go('home');
            return;
          }
        } catch (e) {}
        // Altrimenti minimizza l'app (non la chiude bruscamente)
        try { P.App.minimizeApp ? P.App.minimizeApp() : P.App.exitApp(); } catch (e) {}
      });
    }
  } catch (e) {}

  /* ---- 4. Haptics: piccola vibrazione sui tocchi dei pulsanti principali ---- */
  function haptic(style) {
    try { P.Haptics && P.Haptics.impact({ style: style || 'LIGHT' }); } catch (e) {}
  }
  document.addEventListener('click', (ev) => {
    const b = ev.target.closest && ev.target.closest('.btn, .bell, .club-tab, .me-stat');
    if (b) haptic('LIGHT');
  }, { passive: true });
  window.__haptic = haptic;

  /* ---- 5. Condivisione nativa: usa il foglio di condivisione del sistema ---- */
  // Sostituisce navigator.share con quello nativo Capacitor (più affidabile in app).
  if (P.Share) {
    const origShare = navigator.share && navigator.share.bind(navigator);
    navigator.share = async (data) => {
      try {
        await P.Share.share({
          title: data.title || 'Pàgina',
          text: data.text || '',
          url: data.url || '',
          dialogTitle: 'Condividi'
        });
      } catch (e) {
        if (origShare) return origShare(data);
        throw e;
      }
    };
  }

  /* ---- 6. Notifiche: LOCALI (programmate) + PUSH (remote) ---- */
  // 6a. Notifiche locali: promemoria incontri, curiosità settimanale.
  //     L'app web già calcola questi eventi; qui li rendiamo notifiche vere di sistema.
  window.NativeNotify = {
    async ensurePermission() {
      try {
        if (!P.LocalNotifications) return false;
        const perm = await P.LocalNotifications.requestPermissions();
        return perm && perm.display === 'granted';
      } catch (e) { return false; }
    },
    async schedule(id, title, body, atDate) {
      try {
        if (!P.LocalNotifications) return;
        await P.LocalNotifications.schedule({
          notifications: [{
            id: id,
            title: title,
            body: body,
            schedule: atDate ? { at: new Date(atDate) } : undefined,
            smallIcon: 'ic_stat_icon',
            iconColor: '#1f6b57'
          }]
        });
      } catch (e) {}
    },
    async now(title, body) {
      try {
        if (!P.LocalNotifications) return;
        await P.LocalNotifications.schedule({
          notifications: [{ id: Math.floor(Math.random() * 100000), title, body }]
        });
      } catch (e) {}
    }
  };

  // 6b. Notifiche push (remote): registra il dispositivo e salva il token su Supabase,
  //     così un futuro invio server-side (Edge Function) può raggiungere l'utente.
  async function registerPush() {
    try {
      if (!P.PushNotifications) return;
      const perm = await P.PushNotifications.requestPermissions();
      if (!perm || perm.receive !== 'granted') return;
      await P.PushNotifications.register();

      P.PushNotifications.addListener('registration', async (token) => {
        // Salva il token nel profilo dell'utente su Supabase (se loggato).
        try {
          if (window.supa && window.authUser && token && token.value) {
            await window.supa.from('device_tokens').upsert({
              user_id: window.authUser.id,
              token: token.value,
              platform: platform
            }, { onConflict: 'token' });
          }
        } catch (e) {}
      });

      P.PushNotifications.addListener('pushNotificationReceived', () => {
        // aggiorna il pallino campanella quando arriva una push in foreground
        try { window.updateBellDot && window.updateBellDot(); } catch (e) {}
      });

      P.PushNotifications.addListener('pushNotificationActionPerformed', () => {
        // l'utente ha toccato la notifica: porta alle notifiche in-app
        try { window.go && window.go('notifiche'); } catch (e) {}
      });
    } catch (e) {}
  }

  // Registra le push dopo che l'utente è autenticato.
  // L'app espone startApp(); ci agganciamo con un piccolo polling non invasivo.
  let pushDone = false;
  const pushTimer = setInterval(() => {
    if (pushDone) { clearInterval(pushTimer); return; }
    if (window.authUser && window.mode === 'cloud') {
      pushDone = true;
      clearInterval(pushTimer);
      registerPush();
    }
  }, 1500);
  setTimeout(() => clearInterval(pushTimer), 60000);

  /* ---- 7. Programma le notifiche locali degli incontri entro 48h ---- */
  // Riusa i dati già in memoria dell'app (myMeetings) quando disponibili.
  let notifiedMeetings = {};
  try { notifiedMeetings = JSON.parse(localStorage.getItem('pagina_native_meet_notif') || '{}'); } catch (e) {}
  function scheduleMeetingReminders() {
    try {
      if (!Array.isArray(window.myMeetings)) return;
      const now = Date.now();
      window.myMeetings.forEach((m) => {
        if (!m.date) return;
        const when = new Date(m.date + (m.time ? 'T' + m.time : 'T09:00')).getTime();
        const remindAt = when - 24 * 3600 * 1000; // 24h prima
        const key = 'm' + m.id;
        if (remindAt > now && !notifiedMeetings[key]) {
          const nid = (typeof m.id === 'number' ? m.id : Math.floor(Math.random() * 100000)) % 2147483000;
          window.NativeNotify.schedule(
            nid,
            '📅 Incontro domani',
            (m.title || 'Incontro del club') + (m.place ? ' · ' + m.place : ''),
            remindAt
          );
          notifiedMeetings[key] = 1;
        }
      });
      localStorage.setItem('pagina_native_meet_notif', JSON.stringify(notifiedMeetings));
    } catch (e) {}
  }
  // riprova periodicamente man mano che i dati si caricano
  const meetTimer = setInterval(scheduleMeetingReminders, 8000);
  setTimeout(() => { window.NativeNotify.ensurePermission(); }, 3000);
  setTimeout(() => clearInterval(meetTimer), 120000);

  console.log('[Pàgina] bridge nativo attivo su', platform);
})();
