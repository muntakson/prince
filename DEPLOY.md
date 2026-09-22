# Deployment — Prince of mRNA

**Production URL:** https://prince.aiedus.org  (Cloudflare Full SSL → this server)

- Served as **static files** by nginx (no backend process; survives reboots).
- nginx site: `/etc/nginx/sites-available/prince.aiedus.org` (80 + 443, Cloudflare origin cert).
- Web root: `/var/www/prince/`  (a copy of `build/web/`).
- `.wasm` served as `application/wasm` for streaming compile.

## Redeploy after a code change
```bash
cd /home/jit/mRNA && ./deploy.sh            # export + deploy (add --import after adding assets)
```
`deploy.sh` exports the Web preset, then copies the build to `/var/www/prince/` under
**content-hashed names** (`index.<hash>.wasm/.pck/.js/.png`) and rewrites `index.html`
(`executable`, `mainPack`, `fileSizes`, script/splash src) to point at them. nginx serves the
hashed files with `Cache-Control: public, max-age=31536000, immutable` and pre-gzipped
`.wasm.gz`/`.js.gz` (gzip_static), while `index.html` stays `no-cache`. Old hashed files are
removed. Never copy `build/web/*` by hand any more.

### Payload (2026-09-22)
- wasm 35 MB → 8 MB gzip on the wire; pck **9.9 MB** (was 26 MB: environment textures now import
  as Lossy WebP, `compress/mode=1`, quality 0.85 — note mode 2 is VRAM-compressed S3TC and makes
  the pck *bigger*; `build/` has a `.gdignore` and the export excludes `tools/*,build/*,ChatGPT*`).
- Cloudflare edge-caches `.js`/`.png` but reports `cf-cache-status: DYNAMIC` for `.wasm` and `.pck`
  (not in its default cacheable-extension list). To cache them at the edge add a **Cache Rule** in
  the aiedus.org zone: hostname `prince.aiedus.org` → Eligible for cache, respect origin TTL. The
  stored API token has no access to that zone, so this must be done in the dashboard.
- Chrome's console prints `still waiting on run dependencies: wasm-instantiate` every few seconds
  while the wasm is still downloading/compiling — it is a progress message, not an error. At
  10 Mbps the title screen appeared after ~30 s before the shrink; measure with the session
  scratchpad `loadtime.js <mbps> <url>`.

## Loading splash
- Boot splash image: `assets/ui/splash.png` (720x1280, set in `project.godot` → `boot_splash/image`).
- The web loading page gets its dark-purple background and loads the splash as `index.png?v=N`
  via `html/head_include` in `export_presets.cfg`. Cloudflare caches `index.png` for a day, so
  **bump `?v=N` whenever `splash.png` changes**, or the old splash keeps showing at the edge.

## Second hostname: prince.iotok.org (added 2026-09-22)
- nginx site `/etc/nginx/sites-available/prince.iotok.org` (80 + 443, same `/var/www/prince` root,
  Cloudflare origin cert from `/var/www/sonic/ssl/`). Origin verified with
  `curl -k --resolve prince.iotok.org:443:127.0.0.1 https://prince.iotok.org/`.
- **DNS is NOT created yet**: add a proxied A record `prince` → `121.180.148.105` in the
  Cloudflare zone `iotok.org` (the stored Cloudflare token has no access to that zone).
  Until then the name only works with a local host mapping.

## Web boot audit (Playwright)
- `audit.js <url> <outdir> <w> <h> <tag>` (session scratchpad) monitors console, page errors,
  failed requests, HTTP >= 400, waits for `window.__ss.frame`, screenshots loading / title /
  chapter 1. `keytest.js` focuses the canvas and drives ArrowRight / Space / other arrows,
  measuring movement, state, fps and input latency from `window.__ss`.
  Set `MAP_HOST=prince.iotok.org BASE_URL=https://prince.iotok.org/` to test the origin before DNS exists.
- Expected noise in headless Chrome: SwiftShader "software WebGL" warnings, "GPU stall due to
  ReadPixels", Emscripten "still waiting on run dependencies: wasm-instantiate" while the 35 MB
  wasm compiles, and the aborted Cloudflare `/cdn-cgi/rum` beacon. None are game errors.
- Payload: wasm + js are brotli'd by Cloudflare; `index.pck` (22 MB) is sent raw because it is
  only ~1.4 % compressible (already-compressed textures) — compression/gzip_static would not help.

## Audio assets (added 2026-09-22)
- Sound effects: `assets/audio/*.mp3`; dialogue voice clips: `assets/voice/<id>.mp3` (+ `manifest.json`).
  Both are generated with ElevenLabs by `tools/audio/` (see its README; API key via the `EL` env var).
- Voice mode toggles with the **V** key or the "Voice" buttons (title screen / pause menu); the choice is
  saved in `user://settings.cfg`.
- After adding dialogue lines: `python3 tools/audio/extract_lines.py /tmp/lines.json && EL=... python3 tools/audio/gen_voice.py /tmp/lines.json`,
  then `godot --headless --import` before the export above.

## Languages / voices
- F3 toggles dialogue text + voice between English and Korean (`GameState.lang`, saved in
  `user://settings.cfg`). Korean text: `assets/help/dialogue_ko.json` (keyed by the English line id
  = md5(speaker|text)[:12]); Korean clips: `assets/voice/ko/<id>.mp3` from
  `EL=<key> python3 tools/audio/gen_voice_ko.py` (Korean ElevenLabs voices; Mira uses the shared
  voice "Anna Kim" added to the account). The CJK font subset `assets/fonts/help_ko.otf` must cover
  every Korean string (help, dialogue_ko, clue jsons) — re-subset after editing any of them.

## Korean UI (2026-09-22)
- `assets/help/ui_ko.json` maps every English UI string to Korean; it is loaded into Godot's
  TranslationServer, so controls auto-translate when F3 switches the locale. Add new UI strings
  there (English text as the key) and run `python3 tools/subset_font.py` so the font subset covers
  the new characters. The subset is applied at runtime as the default theme font (the project
  setting `gui/theme/custom_font` stalls the web build — do not use it).
- `deploy.sh` keeps the previous deploy's hashed files for two hours so players mid-load keep working.
- If the live site loads slowly while `curl` from the server is fast, check the Cloudflare→origin
  leg: `curl -o /dev/null -w '%{speed_download}' https://prince.aiedus.org/index.<hash>.pck` vs the
  same file with `--resolve prince.aiedus.org:443:121.180.148.105`. A Cloudflare Cache Rule is the fix.
