# Weylus on Niri: saved test setup

This preserves the temporary laptop/tablet experiment as a reproducible,
side-by-side `weylus-pipewire` command. Stock `programs.weylus` is not replaced.
There is no autostart, compositor patch, or automatic system activation.

## What is preserved

- Upstream [Weylus PR #560](https://github.com/H-M-H/Weylus/pull/560), pinned to
  `808a2a0929be73c96089d50ca0466121619f18b2`. This supplies native PipeWire
  DMA-BUF capture and direct VAAPI import for Niri.
- `patches/client-v2.patch`, containing the exact cumulative frontend changes:
  - Fullscreen/viewport resize updates presentation instead of restarting
    capture and the encoder. Capture resolution changes remain explicit.
  - Stream resets clear queued fragments, ignore stale asynchronous callbacks,
    abort an old pending append, and release old blob URLs.
  - Decoder/SourceBuffer failures request `RestartVideo`, with only one recovery
    request pending. Recovery can produce a brief gray blink.
  - The initial bounded-seeking controller is superseded by
    `patches/smooth-playback.patch`, described below.
  - Recovery diagnostics include readiness, seeking state, time since the last
    seek, and queued fragment count. The script URL busts the old JS cache.
- `launch.sh`: the tested `--wayland-support --pipewire-pipeline dmabuf
  --try-vaapi` path, with the Radeon render node defaulting to
  `/dev/dri/renderD128`.
- `patches/runtime-stability.patch`, addressing the stalled streams observed
  during dummy-display testing:
  - Carry the browser's requested FPS into FFmpeg, the DMA-BUF filter graph,
    MP4 stream metadata, and H.264 timing instead of the old 1000 FPS fallback.
  - Convert 64-bit microsecond timestamps to a 90 kHz media clock. Keep frame
    timestamps non-overlapping even if clock readings repeat; 120 FPS gets exact
    750-tick durations. Report packet/fragment muxing failures instead of ignoring them.
  - Stop on any WebSocket write error, bound a stalled write to three seconds,
    and close the corresponding reader/channels so stale capture threads exit.
  - Rust regressions inspect real software-encoded 60/120 FPS H.264 VUI and MP4
    timestamps, including a repeated clock reading, and exercise connection
    cleanup for broken pipes and against a peer that never reads.
- `patches/cursor-session.patch` fixes cursor/session ordering:
  - Include the saved cursor preference in the initial source-list request,
    before the portal creates a session. An existing checkbox cannot alter a
    session that was already created with the cursor hidden.
  - Refresh and cursor-mode changes request a new sharing session. Rebind to
    its new PipeWire node and send Config after the source list arrives.
  - Preserve exact source selections; only match a changed PipeWire ID when
    its source kind is unambiguous. Do not silently switch to another window.
  - Bust the old client cache; the latest script tag is set by the smooth-playback patch.
- `patches/capture-pacing.patch` removes the 16 ms appsink wait, which exceeds
  the 8.3 ms budget at 120 FPS. The video loop owns pacing; appsinks do not wait
  for presentation timestamps or retain an unnecessary extra backing buffer.
  Cached frames remain available when the compositor has no new damage.
  A real GStreamer regression checks that future timestamps do not delay capture.
- `patches/smooth-playback.patch` replaces routine catch-up seeks:
  - With Lower Latency enabled, speed up to 1.02× above 220 ms of buffered lag
    and return to 1× at 180 ms. Larger lag can use 1.05×; separate hysteresis
    bands and a 250 ms rate-change limit prevent oscillation/repeated writes.
  - Hard seeks are reserved for delayed startup (over 500 ms), an actual
    unplayable timeline gap, or a large backlog (over 1.5 seconds). They have a
    two-second cooldown and target 180 ms behind the last actual buffered edge.
  - With Lower Latency off, use normal 1× playback; retain recovery for gaps
    and backlogs over three seconds. Disabling the setting resets speed immediately.
  - Pause, waiting, end, stream reset, and decoder/fragment recovery restore
    normal speed. Unsupported fractional playback speed falls back once rather
    than throwing repeatedly. Stale callbacks cannot reactivate an old controller.
  - The browser label reads **Lower Latency (smooth catch-up)** and the script
    URL is `lib.js?fix=smooth-v3`. No encoder, transport, or display settings change.
  - Mock regressions include a simulated 120 FPS stream converging without seeks,
    rate bounds/deadbands, cooldowns, mode changes, gaps, resets, and unsupported speed.
- Frontend mock regression tests and launcher isolation/security tests.

No Niri virtual-output support, network changes, or saved desktop recordings
are included.

## Run

From the repository, including while the new files are still untracked:

```sh
nix run path:.#weylus-pipewire
```

The existing temporary server also uses port 1702. Do not stop it just to save
this configuration. To run a second server without disturbing it:

```sh
WEYLUS_WEB_PORT=1703 nix run path:.#weylus-pipewire
```

The launcher prints its tablet URL. In the laptop sharing dialog, select the
**HDP-V104 dummy HDMI display** for an extended tablet desktop, or **Built-in
display** to mirror the laptop. Select **PipeWire Desktop** on the tablet. The
Xwayland `Monitor: eDP-1` entry does not reliably capture the native Wayland
desktop.

After a user-initiated NixOS/Home Manager activation, `weylus-pipewire` is also
installed through `home/modules/weylus.nix`. Stock `weylus` remains available.
No activation is needed for `nix run`.

## Dummy HDMI tablet profile

`home/modules/niri/config.kdl` matches `PNP(BBC) HDP-V104 demoset-1`, rather than
all displays on `HDMI-A-1`, and sets:

- Output mode: **1440×900 at ~120 Hz**, using `mode custom=true`. Niri reports
  **119.939 Hz** for the tested custom timings. The plug only advertises 120 Hz
  at 1920×1080, so this custom mode preserves the tablet's 16:10 aspect ratio
  without stretching. It has been verified on this laptop and dummy plug.
- Niri scale: **1.125**, yielding a **1280×800 logical desktop**, like the
  laptop's built-in display. This changes UI size, not stream resolution.
- About **84% fewer output pixels** than the plug's default 3840×2160 mode.
  This reduces capture/encoding work; actual latency still depends on the
  encoder, tablet decoder, buffering, and network.

The live Niri config points into this repository, so output changes hot-reload
without a system rebuild. A resolution change can interrupt the active stream;
reload the tablet page and reselect the dummy display if needed.

For the browser-local Weylus settings, use a **120 FPS cap**, **Lower Latency
enabled**, and **Stretch video disabled**. Set the video-resolution slider near
**1440×900**; this is a capture limit, not desktop/UI scaling. 120 FPS doubles
frame-processing work compared with 60 FPS; try **60 FPS**, then **30 FPS**, if
decoding or network delivery struggles. A 120 Hz output does not guarantee a
120 FPS stream. Fullscreen provides the intended 16:10 viewport. These settings
are not set by the Niri profile.

If the custom mode stops working after changing hardware, the advertised
`mode "1440x900@59.901"` is the tested 60 Hz fallback; keep `scale 1.125`.

## Defaults and configuration isolation

- Bind address: the laptop's current Tailscale IPv4 address, not all interfaces.
- Port: 1702. Override with `WEYLUS_WEB_PORT`.
- Private configuration root: `$XDG_CONFIG_HOME/weylus-pipewire`, defaulting to
  `~/.config/weylus-pipewire`. Stock `~/.config/weylus` is untouched.
- A new random access code is generated once and kept at
  `$XDG_STATE_HOME/weylus-pipewire/access-code`, defaulting to
  `~/.local/state/weylus-pipewire/access-code`, with mode 0600. The previous
  temporary access code is not copied into the repository.
- Other overrides: `WEYLUS_BIND_ADDRESS`, `WEYLUS_ACCESS_CODE`,
  `WEYLUS_VAAPI_DEVICE`, `WEYLUS_VAAPI_DRM_NODE`, `WEYLUS_LOG_LEVEL`, `GST_DEBUG`,
  `WEYLUS_CAPTURE_STATS`.
- Resolution, FPS cap, and Lower Latency are browser-local settings. A new port
  is a new browser origin: set them again if testing on 1703.

## Verification

```sh
nix build path:.#weylus-pipewire
nix build path:.#checks.x86_64-linux.weylus-pipewire
```

The package also retains upstream's Rust tests and runs the encoder-timing and
connection-cleanup regressions added by the runtime patch, cursor-request
protocol tests, and a real appsrc/appsink clock-pacing test. FFmpeg/ffprobe inspect
actual software-encoded output. The flake check exercises the compiled client
embedded in the package, not a separately maintained JS copy. These tests cannot
establish that a particular Android hardware decoder will behave well.

## Stalls and reconnecting

After updating the package, stop the old server with Ctrl-C and run
`nix run path:.#weylus-pipewire` again; rebuilding alone cannot patch a running
process. Reload the tablet page, approve the dummy HDMI display in the laptop
sharing dialog, and select **PipeWire Desktop**. If a disconnected page stays
visible, tap it to get Weylus's reload prompt.

- Repeated `Failed to send video frame: Broken pipe` messages mean the old
  server kept trying to write to a dead connection. The runtime patch closes
  that connection instead of repeatedly encoding/sending to it.
- `non monotonically increasing dts` messages mean duplicate timestamps reached
  the MP4 muxer. The patch guards monotonic, non-overlapping input timestamps.
- With a 120 FPS cap, the VAAPI debug log should report about `120 FPS`, not
  `RC framerate: 1000/1`. H.264 level selection can now account for that rate.
- Cancelling the sharing dialog can leave only X11 entries available. Those
  capture the wrong desktop under Niri; refresh and approve the dummy output.
- The browser's FPS counter counts incoming video data, not decoded/presented
  frames. High incoming FPS with frozen video can mean playback trouble or
  repeated cached capture frames; it does not establish fresh-frame throughput.
- For capture diagnosis, run
  `WEYLUS_CAPTURE_STATS=1 nix run path:.#weylus-pipewire` after stopping the old
  process. DEBUG logs report fresh, reused, and total capture FPS every three
  seconds. Move a window or scroll on the shared output while measuring: low
  fresh FPS is expected on an idle desktop. No desktop images are logged.
- Capture Cursor changes require approving the sharing dialog again. On Refresh,
  the patched client switches to the new source rather than leaving the old
  stream active. PipeWire node numbers are session-specific, not monitor IDs.
- Keep Niri at 120 Hz, but compare Weylus caps of 60 and 120 FPS to isolate
  tablet decoding/network limits. Lower Latency cannot eliminate network jitter.
- After loading the smooth-playback client, re-enable Lower Latency to test the
  new controller. Its 180 ms target is buffered-media distance, not a measured
  input-to-display latency; capture, transmission, and decoder delay also contribute.

## Remaining issues

Cursor invisibility was traced to requesting a hidden-cursor portal session
before applying the saved preference, then continuing to use the old node after
Refresh. The cursor/session patch addresses both errors. The refreshed stream's
reported 1–2 FPS tablet playback was not a 1–2 FPS compositor ceiling: a temporary
animated window on that same cursor-enabled stream yielded about 81–85 fresh
buffers per second. Kitty's animation rate is not a 120 FPS capture benchmark.
After restarting with the pacing changes, the user reported substantially better
playback. Residual stutters affected both mouse movement and other animations.
Turning Lower Latency off made playback substantially smoother, strongly
implicating routine catch-up seeking. The smooth-playback patch addresses that
controller behavior; its effect on this tablet still needs a restart/reload test.
Keep the working 120 Hz display profile and capture/encoder settings unchanged.

Fullscreen was reported working after the first frontend patch. Decoder error 3
and occasional gray recovery blinks remain unresolved, at both 60 and 120 FPS
caps. This saves the current candidate, not a claim that playback is fixed.
The latest reported tablet errors lacked the diagnostic suffix introduced in
client v2, so an older cached client may still have been in use.

The tested capture path uses DMA-BUF plus VAAPI because the PR's GL uploader
crashed in GStreamer on this laptop. Do not switch the saved launcher to the GL
backend as an assumed fallback. Weylus's built-in Virtual Monitor request is
also unsupported by stock Niri 26.04.

Tailscale initially used DERP Hong Kong. Reconnecting the tablet established a
direct IPv6 path, but measured network jitter remained substantial. No network
or compositor changes are made by this module.
