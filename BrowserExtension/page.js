// Runs only in Yandex Music's main world. No account or playback API tokens.
(() => {
  const handlers = new Map();
  let position;
  let positionAt = performance.now();
  const session = navigator.mediaSession;
  if (!session) return;
  const originalHandler = session.setActionHandler.bind(session);
  session.setActionHandler = (action, handler) => {
    if (handler) handlers.set(action, handler); else handlers.delete(action);
    return originalHandler(action, handler);
  };
  const originalPosition = session.setPositionState.bind(session);
  session.setPositionState = value => {
    position = value;
    positionAt = performance.now();
    return originalPosition(value);
  };
  function publish() {
    const metadata = session.metadata;
    if (!metadata?.title) return;
    const media = [...document.querySelectorAll('audio,video')].find(item => !item.paused);
    const playing = session.playbackState === 'playing' || Boolean(media);
    const elapsed = media?.currentTime ?? (position?.position == null ? undefined : position.position + (playing ? (performance.now() - positionAt) / 1000 * (position.playbackRate ?? 1) : 0));
    const duration = media?.duration ?? position?.duration;
    window.postMessage({ sideA: 'playback', payload: {
      title: metadata.title, artist: metadata.artist || '', album: metadata.album || '',
      artwork: metadata.artwork?.at(-1)?.src, playing,
      duration: Number.isFinite(duration) ? duration : undefined,
      elapsedTime: Number.isFinite(elapsed) ? elapsed : undefined
    } }, location.origin);
  }
  window.addEventListener('message', event => {
    if (event.source !== window || event.origin !== location.origin || event.data?.sideA !== 'command') return;
    const command = event.data.command;
    const playing = session.playbackState === 'playing' || [...document.querySelectorAll('audio,video')].some(item => !item.paused);
    const action = command === 2 ? (playing ? 'pause' : 'play') : command === 4 ? 'nexttrack' : command === 5 ? 'previoustrack' : null;
    if (!action) return;
    if (handlers.has(action)) handlers.get(action)({ action });
    else if (command === 2) {
      const media = document.querySelector('audio,video');
      if (media) { if (playing) media.pause(); else media.play().catch(() => {}); }
    }
    publish();
  });
  setInterval(publish, 2000);
  document.addEventListener('play', publish, true);
  document.addEventListener('pause', publish, true);
})();
