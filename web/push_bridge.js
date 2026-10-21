(() => {
  const workerPath = '/royal-push-sw.js';
  const workerScope = '/royal-push-scope/';

  async function getRegistration() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      throw new Error('Web push is not supported in this browser.');
    }
    return navigator.serviceWorker.register(workerPath, { scope: workerScope });
  }

  function serialize(subscription) {
    if (!subscription) return null;
    const json = subscription.toJSON();
    return {
      endpoint: json.endpoint,
      expirationTime: json.expirationTime ? new Date(json.expirationTime).toISOString() : null,
      keys: json.keys,
    };
  }

  window.royalPushSubscribe = async (publicKey) => {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Notification permission was not granted.');
    const registration = await getRegistration();
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      const normalizedKey = publicKey.replace(/-/g, '+').replace(/_/g, '/');
      const paddedKey = normalizedKey.padEnd(Math.ceil(normalizedKey.length / 4) * 4, '=');
      const applicationServerKey = Uint8Array.from(
        atob(paddedKey),
        (character) => character.charCodeAt(0),
      );
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey,
      });
    }
    return JSON.stringify(serialize(subscription));
  };

  window.royalPushExistingSubscription = async () => {
    const registration = await navigator.serviceWorker.getRegistration(workerScope);
    if (!registration) return '';
    const subscription = await registration.pushManager.getSubscription();
    return subscription ? JSON.stringify(serialize(subscription)) : '';
  };

  window.royalPushUnsubscribe = async () => {
    const registration = await navigator.serviceWorker.getRegistration(workerScope);
    if (!registration) return;
    const subscription = await registration.pushManager.getSubscription();
    if (subscription) await subscription.unsubscribe();
  };
})();
