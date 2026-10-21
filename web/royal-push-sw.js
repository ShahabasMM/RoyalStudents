self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || 'Royal College';
  const options = {
    body: payload.body || 'You have a new update.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { route: payload.route || '/announcements' },
    vibrate: [100, 50, 100],
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const allowedRoutes = new Set(['/announcements', '/online-class', '/doubts', '/results']);
  const route = allowedRoutes.has(event.notification.data?.route)
    ? event.notification.data.route
    : '/announcements';
  const target = `${self.location.origin}/#${route}`;

  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (windows) => {
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin) {
        await client.navigate(target);
        return client.focus();
      }
    }
    return self.clients.openWindow(target);
  }));
});
