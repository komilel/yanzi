const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'weylus-launcher-test-'));
try {
  const mockBin = path.join(root, 'bin');
  const originalConfig = path.join(root, 'config');
  const stateHome = path.join(root, 'state');
  fs.mkdirSync(mockBin);
  fs.mkdirSync(path.join(originalConfig, 'weylus'), { recursive: true });
  const originalFile = path.join(originalConfig, 'weylus', 'weylus.toml');
  fs.writeFileSync(originalFile, 'stock-config-must-not-change\n');

  const mockWeylus = path.join(mockBin, 'weylus');
  fs.writeFileSync(mockWeylus, `#!${process.execPath}
console.log(JSON.stringify({args: process.argv.slice(2), env: Object.fromEntries(
  ['XDG_CONFIG_HOME', 'WEYLUS_VAAPI_DEVICE', 'WEYLUS_VAAPI_DRM_NODE', 'WEYLUS_LOG_LEVEL', 'GST_DEBUG']
  .map(key => [key, process.env[key]]))}));
`, { mode: 0o755 });
  fs.writeFileSync(path.join(mockBin, 'tailscale'), `#!${process.execPath}
if (process.env.FAIL_TAILSCALE) process.exit(1);
if (JSON.stringify(process.argv.slice(2)) !== JSON.stringify(['ip', '-4'])) process.exit(2);
console.log('100.64.0.12');
`, { mode: 0o755 });

  const script = path.join(root, 'launch.sh');
  fs.writeFileSync(script, fs.readFileSync(process.argv[2] || path.join(__dirname, '../launch.sh'), 'utf8').replace('@weylus@', mockWeylus));
  const env = { ...process.env, HOME: path.join(root, 'home'), XDG_CONFIG_HOME: originalConfig,
    XDG_STATE_HOME: stateHome, PATH: mockBin + path.delimiter + process.env.PATH };
  for (const key of ['WEYLUS_ACCESS_CODE', 'WEYLUS_BIND_ADDRESS', 'WEYLUS_WEB_PORT',
    'WEYLUS_VAAPI_DEVICE', 'WEYLUS_VAAPI_DRM_NODE', 'WEYLUS_LOG_LEVEL', 'GST_DEBUG', 'FAIL_TAILSCALE'])
    delete env[key];
  const run = overrides => spawnSync('bash', [script, '--extra-argument'], {
    env: { ...env, ...overrides }, encoding: 'utf8', timeout: 10000,
  });
  const parse = result => {
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout.trim().split('\n').at(-1));
  };

  const firstResult = run({});
  const first = parse(firstResult);
  const codeFile = path.join(stateHome, 'weylus-pipewire/access-code');
  const accessCode = fs.readFileSync(codeFile, 'utf8');
  assert.match(accessCode, /^[0-9a-f]{32}$/);
  assert.equal(fs.statSync(codeFile).mode & 0o777, 0o600);
  assert.deepEqual(first.args, ['--no-gui', '--wayland-support', '--pipewire-pipeline', 'dmabuf',
    '--try-vaapi', '--bind-address', '100.64.0.12', '--web-port', '1702',
    '--access-code', accessCode, '--extra-argument']);
  assert.equal(first.env.XDG_CONFIG_HOME, path.join(originalConfig, 'weylus-pipewire'));
  assert.equal(first.env.WEYLUS_VAAPI_DEVICE, '/dev/dri/renderD128');
  assert.equal(first.env.WEYLUS_VAAPI_DRM_NODE, '/dev/dri/renderD128');
  assert.equal(first.env.WEYLUS_LOG_LEVEL, 'DEBUG');
  assert.equal(first.env.GST_DEBUG, '2');
  assert.match(firstResult.stdout, new RegExp(`Tablet URL: http://100\\.64\\.0\\.12:1702/\\?access_code=${accessCode}`));

  const second = parse(run({}));
  assert.equal(second.args[second.args.indexOf('--access-code') + 1], accessCode);
  assert.equal(fs.readFileSync(originalFile, 'utf8'), 'stock-config-must-not-change\n');

  const overrideResult = run({ WEYLUS_ACCESS_CODE: 'explicit-test-code',
    WEYLUS_BIND_ADDRESS: '2001:db8::9', WEYLUS_WEB_PORT: '1703',
    WEYLUS_VAAPI_DEVICE: '/dev/dri/renderD129', FAIL_TAILSCALE: '1' });
  const override = parse(overrideResult);
  assert.equal(override.args[override.args.indexOf('--bind-address') + 1], '2001:db8::9');
  assert.equal(override.args[override.args.indexOf('--web-port') + 1], '1703');
  assert.equal(override.args[override.args.indexOf('--access-code') + 1], 'explicit-test-code');
  assert.equal(override.env.WEYLUS_VAAPI_DRM_NODE, '/dev/dri/renderD129');
  assert.match(overrideResult.stdout, /http:\/\/\[2001:db8::9\]:1703\//);
  assert.equal(fs.readFileSync(codeFile, 'utf8'), accessCode, 'environment override does not overwrite stored code');

  const missingTailscale = run({ FAIL_TAILSCALE: '1' });
  assert.equal(missingTailscale.status, 1);
  assert.match(missingTailscale.stderr, /No Tailscale address available/);
  assert.equal(missingTailscale.stdout, '', 'do not launch an unexpectedly exposed server');
  console.log('PASS: launcher defaults, isolated config, private persistent access code, overrides, missing Tailscale');
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
