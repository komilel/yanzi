const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
assert(process.env.CLIENT_JS, 'Set CLIENT_JS to the compiled Weylus client being tested');
const code = fs.readFileSync(process.env.CLIENT_JS, 'utf8');

class Events {
  constructor() { this.listeners = {}; }
  addEventListener(name, callback) { (this.listeners[name] ??= []).push(callback); }
  emit(name) { for (const callback of this.listeners[name] ?? []) callback({}); }
}
class Buffer extends Events {
  constructor() {
    super(); this.updating = false; this.appended = [];
    this.buffered = { length: 0 }; this.onerror = null;
  }
  appendBuffer(data) {
    if (this.failAppend) throw Error('malformed fragment');
    this.appended.push(data); this.updating = true;
  }
  abort() { this.updating = false; this.emit('updateend'); }
  remove() { this.updating = true; }
}

function harness() {
  const sources = [], revoked = [], sent = [];
  class Media extends Events {
    constructor() { super(); this.readyState = 'closed'; this.buffers = []; sources.push(this); }
    static isTypeSupported() { return true; }
    addSourceBuffer() { const buffer = new Buffer(); this.buffers.push(buffer); return buffer; }
    open() { this.readyState = 'open'; this.emit('sourceopen'); }
  }
  const video = new Events();
  Object.assign(video, { seekable: { length: 0 }, buffered: { length: 0 }, error: null,
    seeking: false, paused: false, ended: false, readyState: 3 });
  let currentTime = 0, playbackRate = 1;
  const seeks = [], rateAttempts = [];
  Object.defineProperty(video, 'currentTime', {
    get: () => currentTime, set: value => { currentTime = value; seeks.push(value); },
  });
  Object.defineProperty(video, 'playbackRate', {
    get: () => playbackRate, set: value => {
      rateAttempts.push(value);
      if (video.rejectRate && value !== 1) throw Error('unsupported playback rate');
      playbackRate = value;
    },
  });
  const socket = { readyState: 1, send: data => sent.push(data) };
  let configurations = 0, layouts = 0, clock = 0;
  const context = vm.createContext({
    window: { MediaSource: Media, innerWidth: 800, innerHeight: 500, devicePixelRatio: 2 },
    WebSocket: { OPEN: 1 },
    URL: { createObjectURL: () => 'blob:' + sources.length, revokeObjectURL: url => revoked.push(url) },
    performance: { now: () => clock }, console,
    testSocket: socket, testVideo: video,
    testSettings: { check_aggressive_seek: Object.assign(new Events(), { checked: false }), send_server_config: () => configurations++ },
    testLayout: () => layouts++,
  });
  vm.runInContext(code, context);
  vm.runInContext('settings = testSettings; log = () => {}; stretch_video = testLayout; handle_messages(testSocket, testVideo, () => {}, () => {}, () => {});', context);
  return {
    context, sources, video, sent, revoked, seeks, rateAttempts,
    setTime: seconds => currentTime = seconds,
    receive: data => socket.onmessage({ data }),
    configs: () => configurations, layouts: () => layouts,
    advance: milliseconds => clock += milliseconds,
  };
}

// Queued fragments from the old stream must never enter the new SourceBuffer.
{
  const h = harness();
  h.receive('"NewVideo"'); h.receive({ id: 'old' });
  h.receive('"NewVideo"'); h.receive({ id: 'new' });
  h.sources[0].open();
  assert.equal(h.sources[0].buffers.length, 0, 'stale sourceopen ignored');
  h.sources[1].open();
  assert.deepEqual(h.sources[1].buffers[0].appended, [{ id: 'new' }]);
  assert.deepEqual(h.revoked, ['blob:1']);
}

// Late events from an old SourceBuffer cannot drain the current generation.
{
  const h = harness();
  h.receive('"NewVideo"'); h.sources[0].open(); h.receive({ id: 'a' });
  const oldBuffer = h.sources[0].buffers[0];
  h.receive('"NewVideo"'); h.sources[1].open(); h.receive({ id: 'b' }); h.receive({ id: 'c' });
  const currentBuffer = h.sources[1].buffers[0];
  currentBuffer.updating = false;
  oldBuffer.emit('updateend');
  assert.deepEqual(currentBuffer.appended, [{ id: 'b' }]);
  currentBuffer.emit('updateend');
  assert.deepEqual(currentBuffer.appended, [{ id: 'b' }, { id: 'c' }]);
}

// Error handlers are installed even when onerror initially equals null.
{
  const h = harness(); h.receive('"NewVideo"'); h.sources[0].open();
  const buffer = h.sources[0].buffers[0];
  buffer.emit('error'); buffer.emit('error');
  assert.deepEqual(h.sent, ['"RestartVideo"'], 'only one restart request pending');
  h.receive({ id: 'discarded-before-reset' });
  assert.equal(buffer.appended.length, 0);
  h.receive('"NewVideo"'); h.sources[1].open(); h.receive({ id: 'fresh' });
  assert.deepEqual(h.sources[1].buffers[0].appended, [{ id: 'fresh' }]);
}

// Synchronous append errors and decoder errors request a new video stream.
{
  const h = harness(); h.receive('"NewVideo"'); h.sources[0].open();
  h.sources[0].buffers[0].failAppend = true; h.receive({ id: 'bad' });
  assert.deepEqual(h.sent, ['"RestartVideo"']);
}
{
  const h = harness(); h.video.error = { code: 3, message: 'decode failure' }; h.video.emit('error');
  assert.deepEqual(h.sent, ['"RestartVideo"']);
}

// Fullscreen/viewport resizing updates layout, not server configuration.
{
  const h = harness(); h.context.testCanvas = {};
  vm.runInContext('resize_video_viewport(testCanvas); window.innerWidth = 1280; window.innerHeight = 800; resize_video_viewport(testCanvas);', h.context);
  assert.equal(h.context.testCanvas.width, 2560);
  assert.equal(h.context.testCanvas.height, 1600);
  assert.equal(h.configs(), 0);
  assert.equal(h.layouts(), 2);
}
function controller(h, initialized = false) {
  vm.runInContext('testCatchUpState = create_playback_catch_up_state();', h.context);
  h.context.testCatchUpState.initialized = initialized;
  return low => vm.runInContext(`catch_up_video(testVideo, ${low}, testCatchUpState);`, h.context);
}

// Routine lag is corrected by speed, never a periodic decoder-flushing seek.
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.65);
  const catchUp = controller(h);
  for (let i = 0; i < 1200; i++) { catchUp(true); h.advance(1000 / 120); }
  assert.equal(h.video.currentTime, 1.65);
  assert.equal(h.video.playbackRate, 1.02);
  assert.deepEqual(h.seeks, [], 'ordinary catch-up never jumps the playhead');
  assert.deepEqual(h.rateAttempts, [1.02], 'do not reassign speed on every fragment');
}

// A simulated 120 FPS stream converges smoothly into the 180–220 ms deadband.
{
  const h = harness(); let edge = 2;
  h.video.buffered = { length: 1, start: () => 0, end: () => edge };
  h.setTime(1.6);
  const catchUp = controller(h);
  for (let i = 0; i < 2400; i++) {
    const step = 1 / 120;
    edge += step;
    h.setTime(h.video.currentTime + step * h.video.playbackRate);
    h.advance(step * 1000); catchUp(true);
    assert(edge - h.video.currentTime >= 0.17, 'keep playable data ahead');
    assert(h.video.playbackRate >= 1 && h.video.playbackRate <= 1.05);
  }
  assert.equal(h.video.playbackRate, 1);
  assert(edge - h.video.currentTime <= 0.22);
  assert.deepEqual(h.seeks, []);
}

// Both speed levels have hysteresis; tiny lag changes do not oscillate modes.
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.3);
  const catchUp = controller(h, true);
  catchUp(true); assert.equal(h.video.playbackRate, 1.05);
  h.setTime(1.51); h.advance(300); catchUp(true);
  assert.equal(h.video.playbackRate, 1.05, 'retain high speed inside its deadband');
  h.setTime(1.62); h.advance(300); catchUp(true);
  assert.equal(h.video.playbackRate, 1.02);
  h.setTime(1.8); catchUp(true);
  assert.equal(h.video.playbackRate, 1.02, 'retain catch-up until 180 ms');
  h.setTime(1.825); catchUp(true); assert.equal(h.video.playbackRate, 1);
  h.setTime(1.79); h.advance(300); catchUp(true);
  assert.equal(h.video.playbackRate, 1, 'do not reactivate below 220 ms');
  h.setTime(1.75); catchUp(true); assert.equal(h.video.playbackRate, 1.02);
  assert.deepEqual(h.seeks, []);
}

// Limit speed changes to four per second; restoring 1x is always immediate.
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.65);
  const catchUp = controller(h); catchUp(true);
  h.setTime(1.3); h.advance(100); catchUp(true);
  assert.equal(h.video.playbackRate, 1.02);
  h.advance(150); catchUp(true); assert.equal(h.video.playbackRate, 1.05);
  h.setTime(1.97); h.advance(1); catchUp(true);
  assert.equal(h.video.playbackRate, 1, 'never speed up into an underrun');
  assert.deepEqual(h.seeks, []);
}

// A delayed startup may align once; emergency seeks have a two-second cooldown.
{
  const h = harness(); let edge = 2;
  h.video.buffered = { length: 1, start: () => 0, end: () => edge };
  h.setTime(1.2);
  const catchUp = controller(h); catchUp(true);
  assert.equal(h.video.currentTime, 1.82);
  assert.equal(h.video.playbackRate, 1);
  edge = 5; h.advance(100); catchUp(true);
  assert.deepEqual(h.seeks, [1.82]);
  h.advance(1900); catchUp(true);
  assert.deepEqual(h.seeks, [1.82, 4.82]);
}

// During normal playback, even a one-second backlog does not cause a seek.
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(0.8);
  const catchUp = controller(h, true); catchUp(true);
  assert.equal(h.video.playbackRate, 1.05); assert.deepEqual(h.seeks, []);
  h.setTime(0); h.advance(300); catchUp(true);
  assert.equal(h.video.currentTime, 1.82, 'recover a backlog over 1.5 seconds');
  assert.equal(h.video.playbackRate, 1);
}

// Lower Latency off means 1x playback, retaining only the old >3 s recovery.
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 5 };
  h.setTime(3); h.video.playbackRate = 1.05;
  const catchUp = controller(h); catchUp(false);
  assert.equal(h.video.currentTime, 3); assert.equal(h.video.playbackRate, 1);
  h.setTime(0); catchUp(false);
  assert.equal(h.video.currentTime, 4.75);
}

// Recover real gaps, but do not skip an older range that is still playable.
{
  const h = harness();
  h.video.buffered = { length: 2, start: i => i ? 2.1 : 0, end: i => i ? 2.3 : 2 };
  h.setTime(1.7);
  const catchUp = controller(h, true); catchUp(true);
  assert.deepEqual(h.seeks, [], 'continue the older playable range');
  h.setTime(1.999); h.advance(300); catchUp(true);
  assert(Math.abs(h.video.currentTime - 2.12) < 1e-9);
  assert.equal(h.video.playbackRate, 1);
}
{
  const h = harness();
  h.video.buffered = { length: 2, start: i => i ? 10 : 0, end: i => i ? 10.05 : 2 };
  h.setTime(5);
  controller(h, true)(true);
  assert.equal(h.video.currentTime, 10, 'clamp recovery to the actual short range');
}

// Suspend speed correction for errors, pauses, seeking, starvation, and invalid ranges.
for (const override of [
  { error: { code: 3 } }, { seeking: true }, { paused: true }, { ended: true },
  { readyState: 1 }, { readyState: 2 }, { buffered: { length: 0 } },
  { buffered: { length: 1, start: () => 0, end: () => Infinity } },
  { buffered: { length: 1, start: () => NaN, end: () => 2 } },
  { buffered: { length: 1, start: () => 2, end: () => 1 } },
]) {
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.65);
  const catchUp = controller(h); catchUp(true);
  assert.equal(h.video.playbackRate, 1.02);
  Object.assign(h.video, override); catchUp(true);
  assert.equal(h.video.playbackRate, 1);
  assert.deepEqual(h.seeks, []);
}
{
  const h = harness();
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.video.playbackRate = 1.05; h.setTime(Infinity);
  controller(h)(true);
  assert.equal(h.video.playbackRate, 1); assert.deepEqual(h.seeks, []);
}

// A browser rejecting fractional speed falls back once, without exception loops.
{
  const h = harness(); h.video.rejectRate = true;
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.65);
  const catchUp = controller(h); catchUp(true);
  assert.equal(h.video.playbackRate, 1);
  assert.equal(h.context.testCatchUpState.rate_supported, false);
  const attempts = h.rateAttempts.length;
  for (let i = 0; i < 100; i++) { h.advance(100); catchUp(true); }
  assert.equal(h.rateAttempts.length, attempts);
  assert.deepEqual(h.seeks, []);
  h.setTime(0); catchUp(true);
  assert.equal(h.video.currentTime, 1.82, 'emergency recovery still works');
}

// Incoming data cannot drive catch-up before SourceBuffer has committed it.
// Mode changes restore normal speed immediately, without restarting the server.
{
  const h = harness();
  const checkbox = h.context.testSettings.check_aggressive_seek;
  checkbox.checked = true;
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.video.seekable = { length: 1, start: () => 0, end: () => 99 };
  h.setTime(1.65);
  h.receive('"NewVideo"'); h.sources[0].open(); h.receive({ id: 'frame' });
  assert.equal(h.video.playbackRate, 1);
  const buffer = h.sources[0].buffers[0];
  buffer.updating = false; buffer.emit('updateend');
  assert.equal(h.video.playbackRate, 1.02);
  assert.deepEqual(h.seeks, [], 'use buffered, not seekable');
  checkbox.checked = false; checkbox.emit('change');
  assert.equal(h.video.playbackRate, 1);
  assert.equal(h.configs(), 0); assert.deepEqual(h.sent, []);
}

// Pause/waiting/ended events reset speed even when no new data arrives.
for (const event of ['pause', 'waiting', 'ended']) {
  const h = harness(); h.video.playbackRate = 1.05;
  h.video.emit(event); assert.equal(h.video.playbackRate, 1);
}

// Restart resets speed/state, and stale callbacks cannot revive old catch-up.
{
  const h = harness(); h.context.testSettings.check_aggressive_seek.checked = true;
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 };
  h.setTime(1.65);
  h.receive('"NewVideo"'); h.sources[0].open();
  const oldBuffer = h.sources[0].buffers[0]; oldBuffer.emit('updateend');
  assert.equal(h.video.playbackRate, 1.02);
  h.receive('"NewVideo"'); assert.equal(h.video.playbackRate, 1);
  oldBuffer.emit('updateend'); assert.equal(h.video.playbackRate, 1);
  h.video.buffered = { length: 1, start: () => 0, end: () => 0.2 }; h.setTime(0);
  h.sources[1].open(); h.sources[1].buffers[0].emit('updateend');
  assert.equal(h.video.playbackRate, 1);
}
{
  const h = harness(); h.video.playbackRate = 1.05;
  h.video.error = { code: 3, message: 'decode failure' }; h.video.emit('error');
  assert.equal(h.video.playbackRate, 1);
  assert.deepEqual(h.sent, ['"RestartVideo"']);
}
{
  const h = harness(); const checkbox = h.context.testSettings.check_aggressive_seek;
  checkbox.checked = true; h.video.rejectRate = true;
  h.video.buffered = { length: 1, start: () => 0, end: () => 2 }; h.setTime(1.65);
  h.receive('"NewVideo"'); h.sources[0].open();
  h.sources[0].buffers[0].emit('updateend');
  assert.equal(h.video.playbackRate, 1);
  h.video.rejectRate = false;
  h.receive('"NewVideo"'); h.sources[1].open();
  const buffer = h.sources[1].buffers[0]; buffer.emit('updateend');
  assert.equal(h.video.playbackRate, 1.02, 'new stream retries supported speed control');
  buffer.emit('error');
  assert.equal(h.video.playbackRate, 1);
  checkbox.emit('change');
  assert.equal(h.video.playbackRate, 1, 'do not reactivate catch-up while recovery is pending');
  assert.deepEqual(h.sent, ['"RestartVideo"']);
}

// Portal source requests include cursor preference before any Config exists.
{
  const h = harness();
  h.context.testSettings.webSocket = h.context.testSocket;
  h.context.testSettings.checks = new Map([['capture_cursor', { checked: true }]]);
  vm.runInContext('Settings.prototype.refresh_capturables.call(testSettings)', h.context);
  assert.deepEqual(h.sent, ['{"GetCapturableListWithCursor":true}']);
  h.context.testSettings.checks.get('capture_cursor').checked = false;
  vm.runInContext('Settings.prototype.refresh_capturables.call(testSettings)', h.context);
  assert.equal(h.sent[1], '{"GetCapturableListWithCursor":false}');
  h.context.testSocket.readyState = 0;
  vm.runInContext('Settings.prototype.refresh_capturables.call(testSettings)', h.context);
  assert.equal(h.sent.length, 2, 'do not send on a connecting/closed socket');
}

// Portal node IDs change on refresh; select and start the new unambiguous source.
{
  const h = harness();
  h.context.document = { createElement: () => ({}) };
  const select = {
    selectedOptions: [{ textContent: 'Pipewire Desktop, path: 114' }],
    value: '0', appendChild: () => {},
  };
  h.context.testSettings.capturable_select = select;
  vm.runInContext('Settings.prototype.onCapturableList.call(testSettings, ["Pipewire Desktop, path: 120", "Monitor: eDP-1"])', h.context);
  assert.equal(select.value, '0');
  assert.equal(h.configs(), 1, 'start the refreshed stream, rather than leave the old node running');
}

// Cold startup starts capture only after the first source list has arrived.
{
  const h = harness();
  h.context.document = { createElement: () => ({}) };
  const select = { selectedOptions: [], value: '', appendChild: () => {} };
  h.context.testSettings.capturable_select = select;
  assert.equal(h.configs(), 0);
  vm.runInContext('Settings.prototype.onCapturableList.call(testSettings, ["Pipewire Desktop, path: 120"])', h.context);
  assert.equal(select.value, '0');
  assert.equal(h.configs(), 1);
}

// Never automatically switch to another window or an ambiguous monitor.
{
  const h = harness();
  const choose = (current, names) => {
    h.context.testCurrent = current; h.context.testNames = names;
    return vm.runInContext('find_capturable_index(testCurrent, testNames)', h.context);
  };
  assert.equal(choose('Monitor: eDP-1', ['Pipewire Desktop, path: 120', 'Monitor: eDP-1']), 1);
  assert.equal(choose('Pipewire Desktop, path: 114', ['Pipewire Desktop, path: 120', 'Pipewire Desktop, path: 121']), -1);
  assert.equal(choose('Pipewire Desktop, path: 114', ['Pipewire Window, path: 120']), -1);
  assert.equal(choose('Closed app', ['Another app']), -1);
  assert.equal(choose(undefined, []), -1);
  h.context.document = { createElement: () => ({}) };
  const select = { selectedOptions: [{ textContent: 'Closed app' }], value: '0', appendChild: () => {} };
  h.context.testSettings.capturable_select = select;
  vm.runInContext('Settings.prototype.onCapturableList.call(testSettings, ["Another app"])', h.context);
  assert.equal(select.value, '');
  assert.equal(h.configs(), 0);
}
console.log('PASS: frontend regression suite (stream recovery, fullscreen, smooth catch-up, cursor startup, refreshed source selection)');
