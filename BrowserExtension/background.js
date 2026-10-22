let port;
function connect() {
  if (port) return port;
  port = chrome.runtime.connectNative('local.sidea.browser');
  port.onDisconnect.addListener(() => {
    console.info('Vinyl bridge disconnected:', chrome.runtime.lastError?.message || 'closed');
    port = null;
  });
  port.onMessage.addListener(message => {
    const tabId = Number(message.session);
    if (Number.isInteger(tabId) && [2, 4, 5].includes(message.command)) {
      chrome.tabs.sendMessage(tabId, { type: 'control', command: message.command }).catch(() => {});
    }
  });
  return port;
}
chrome.runtime.onMessage.addListener((message, sender) => {
  if (!sender.tab || sender.frameId !== 0) return;
  const origin = new URL(sender.url || sender.tab.url).origin;
  if (!['https://music.yandex.ru', 'https://music.yandex.com', 'https://music.yandex.kz', 'https://music.yandex.uz', 'https://music.yandex.by'].includes(origin)) return;
  if (typeof message?.title !== 'string' || !message.title || message.title.length > 2000) return;
  const payload = {
    title: message.title, artist: String(message.artist || '').slice(0, 2000),
    album: String(message.album || '').slice(0, 2000), playing: message.playing === true,
    session: String(sender.tab.id),
    artwork: typeof message.artwork === 'string' ? message.artwork.slice(0, 4096) : undefined,
    duration: Number.isFinite(message.duration) ? Math.max(0, message.duration) : undefined,
    elapsedTime: Number.isFinite(message.elapsedTime) ? Math.max(0, message.elapsedTime) : undefined
  };
  try { connect().postMessage(payload); } catch { port = null; }
});
