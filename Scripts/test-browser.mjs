import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const posted = [], events = new Map();
const mediaSession = {
  metadata: { title: 'Test song', artist: 'Test artist', album: 'Test album', artwork: [] },
  playbackState: 'playing', setActionHandler() {}, setPositionState() {}
};
let publish;
const window = { postMessage: value => posted.push(value), addEventListener: (name, handler) => events.set(name, handler) };
vm.runInNewContext(readFileSync('BrowserExtension/page.js', 'utf8'), {
  navigator: { mediaSession }, performance: { now: () => 1000 },
  document: { querySelectorAll: () => [], addEventListener() {} },
  window, location: { origin: 'https://music.yandex.ru' },
  setInterval: handler => { publish = handler; }
});
publish();
assert.equal(posted[0].payload.title, 'Test song');
assert.equal(posted[0].payload.playing, true);
let called = false;
mediaSession.setActionHandler('pause', () => { called = true; });
events.get('message')({ source: window, origin: 'https://music.yandex.ru', data: { sideA: 'command', command: 2 } });
assert.equal(called, true);
called = false;
events.get('message')({ source: window, origin: 'https://evil.example', data: { sideA: 'command', command: 2 } });
assert.equal(called, false);

let listener;
const messages = [];
vm.runInNewContext(readFileSync('BrowserExtension/background.js', 'utf8'), {
  URL, console, chrome: { runtime: {
    onMessage: { addListener: value => { listener = value; } },
    connectNative: () => ({ onDisconnect: { addListener() {} }, onMessage: { addListener() {} }, postMessage: value => messages.push(value) })
  } }
});
listener({ title: 'Valid', playing: true }, { tab: { id: 1 }, frameId: 0, url: 'https://music.yandex.ru/album/123' });
assert.equal(messages.length, 1);
assert.equal(messages[0].session, '1');
listener({ title: 'Invalid' }, { tab: { id: 2 }, frameId: 0, url: 'https://evil.example/' });
assert.equal(messages.length, 1);
console.log('Browser bridge tests passed: metadata, controls, origin validation, tab attribution.');
