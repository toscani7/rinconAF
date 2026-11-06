/* RincónAF — service worker
   1) Hace que la página se pueda instalar como app (Android, Brave, iPhone).
   2) Muestra los avisos (notificaciones push) aunque RincónAF esté cerrado, y al tocarlos abre lo que corresponde.
   No guarda nada: todo se pide siempre a internet, así cada cambio que subís se ve al instante. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.mode !== 'navigate') return;                       // fotos, Supabase, etc.: siguen igual que siempre
  e.respondWith(fetch(e.request).catch(() => new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>RincónAF</title><body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#000;color:#ccc;font-family:Verdana,sans-serif;text-align:center;padding:20px">' +
    '<div><p style="font-size:18px;color:#fff;margin:0 0 8px">RincónAF</p><p style="margin:0">no hay conexión a internet.<br>cuando vuelva, abrí de nuevo.</p></div>',
    {headers: {'Content-Type': 'text/html; charset=utf-8'}})));
});

// Aviso que llega del servidor
self.addEventListener('push', e => {
  let d = {}; try { d = e.data ? e.data.json() : {}; } catch { d = {title: 'RincónAF', body: e.data ? e.data.text() : ''}; }
  e.waitUntil((async () => {
    const ua = self.navigator.userAgent, apple = /iPhone|iPad|iPod|Macintosh/.test(ua) && !/Chrome|CriOS|Android|Firefox|FxiOS/.test(ua);
    const ventanas = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    // Si justo estás mirando RincónAF no hace falta el aviso (la página ya suena). En iPhone siempre se muestra (Apple lo exige).
    if (!apple && ventanas.some(c => c.visibilityState === 'visible' && c.focused)) return;
    await self.registration.showNotification(d.title || 'RincónAF', {
      body: d.body || '', icon: '/icon-192.png', badge: '/icon-192.png', tag: d.tag || undefined, renotify: !!d.tag,
      data: {url: typeof d.url === 'string' && d.url.startsWith('/') ? d.url : '/'}});
  })());
});

// Tocar el aviso: abre RincónAF en esa conversación / notificación (o trae al frente la que ya estaba abierta)
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const destino = new URL(e.notification.data && e.notification.data.url || '/', self.location.origin).href;
  e.waitUntil((async () => {
    const ventanas = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
    const v = ventanas.find(c => new URL(c.url).origin === self.location.origin);
    if (v){ await v.focus(); v.postMessage({ir: new URL(destino).hash}); return; }
    await self.clients.openWindow(destino);
  })());
});
