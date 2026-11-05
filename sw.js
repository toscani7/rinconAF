/* rinconAF — service worker mínimo (lo piden Android/Brave para instalar la página como app).
   No guarda nada: todo se pide siempre a internet, así cada cambio que subís se ve al instante.
   Solo si no hay conexión al abrir la app, muestra un aviso en vez de la pantalla de error del navegador. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.mode !== 'navigate') return;                       // fotos, Supabase, etc.: siguen igual que siempre
  e.respondWith(fetch(e.request).catch(() => new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>rinconAF</title><body style="margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#000;color:#ccc;font-family:Verdana,sans-serif;text-align:center;padding:20px">' +
    '<div><p style="font-size:18px;color:#fff;margin:0 0 8px">rinconAF</p><p style="margin:0">no hay conexión a internet.<br>cuando vuelva, abrí de nuevo.</p></div>',
    {headers: {'Content-Type': 'text/html; charset=utf-8'}})));
});
