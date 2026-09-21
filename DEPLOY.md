# Deployment — Prince of mRNA

**Production URL:** https://prince.aiedus.org  (Cloudflare Full SSL → this server)

- Served as **static files** by nginx (no backend process; survives reboots).
- nginx site: `/etc/nginx/sites-available/prince.aiedus.org` (80 + 443, Cloudflare origin cert).
- Web root: `/var/www/prince/`  (a copy of `build/web/`).
- `.wasm` served as `application/wasm` for streaming compile.

## Redeploy after a code change
```bash
GODOT=/home/jit/bin/godot
$GODOT --headless --path /home/jit/mRNA --export-release "Web" /home/jit/mRNA/build/web/index.html
cp -r /home/jit/mRNA/build/web/* /var/www/prince/
# nginx reload not needed for static file changes
```

## Loading splash
- Boot splash image: `assets/ui/splash.png` (720x1280, set in `project.godot` → `boot_splash/image`).
- The web loading page gets its dark-purple background and loads the splash as `index.png?v=N`
  via `html/head_include` in `export_presets.cfg`. Cloudflare caches `index.png` for a day, so
  **bump `?v=N` whenever `splash.png` changes**, or the old splash keeps showing at the edge.
