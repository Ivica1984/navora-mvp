// SIG2 (ADR-076): shows the one fixed NAVORA push text and opens /field on a tap. Nothing else: no caching, no
// fetch handler, no data stored. The text is fixed here as well, so a message is never shown with other content.
const TEXT = "NAVORA: Ein Sicherheitssignal wartet auf dich.";
const URL_ON_TAP = "/field?von=push";

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("push", (event) => {
  event.waitUntil(
    self.registration.showNotification("NAVORA", {
      body: TEXT,
      tag: "navora-signal",
      renotify: true,
      requireInteraction: true,
      data: { url: URL_ON_TAP },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ("navigate" in w && new URL(w.url).origin === self.location.origin) {
          return w.navigate(URL_ON_TAP).then((c) => (c ? c.focus() : self.clients.openWindow(URL_ON_TAP)));
        }
      }
      return self.clients.openWindow(URL_ON_TAP);
    }),
  );
});
