window.addEventListener('message', event => {
  if (event.source !== window || event.origin !== location.origin || event.data?.sideA !== 'playback') return;
  chrome.runtime.sendMessage(event.data.payload).catch(() => {});
});
chrome.runtime.onMessage.addListener(message => {
  if (message.type === 'control' && [2, 4, 5].includes(message.command)) {
    window.postMessage({ sideA: 'command', command: message.command }, location.origin);
  }
});
