# Deployment — The Secret Scroll

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
