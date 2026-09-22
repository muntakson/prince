#!/usr/bin/env bash
# Export the web build and deploy it to the nginx web root with CONTENT-HASHED
# file names (index.<hash>.wasm / .pck / .js / .png) so browsers and Cloudflare
# can cache the big files for a year, while index.html stays no-cache and
# points at the current hashes. Also pre-gzips the wasm + js for gzip_static.
#   ./deploy.sh            export + deploy
#   ./deploy.sh --import   run the resource importer first (after adding assets)
set -euo pipefail
GODOT=${GODOT:-/home/jit/bin/godot}
PROJ=$(cd "$(dirname "$0")" && pwd)
BUILD=$PROJ/build/web
WEB=${WEB:-/var/www/prince}

if [[ "${1:-}" == "--import" ]]; then
	"$GODOT" --headless --path "$PROJ" --import > /tmp/prince-import.log 2>&1 || true
fi
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$BUILD/index.html" > /tmp/prince-export.log 2>&1
grep -qi "error" /tmp/prince-export.log && { echo "export reported errors:"; grep -i error /tmp/prince-export.log | head; }
[[ -s $BUILD/index.wasm && -s $BUILD/index.pck ]] || { echo "export failed (see /tmp/prince-export.log)"; exit 1; }

h() { md5sum "$1" | cut -c1-10; }
HW=$(h "$BUILD/index.wasm"); HP=$(h "$BUILD/index.pck"); HJ=$(h "$BUILD/index.js"); HI=$(h "$BUILD/index.png")
mkdir -p "$WEB"
cp "$BUILD/index.wasm"             "$WEB/index.$HW.wasm"
cp "$BUILD/index.audio.worklet.js" "$WEB/index.$HW.audio.worklet.js"
cp "$BUILD/index.js"               "$WEB/index.$HJ.js"
cp "$BUILD/index.js"               "$WEB/index.$HW.js"   # the engine may look for <executable>.js
cp "$BUILD/index.pck"              "$WEB/index.$HP.pck"
cp "$BUILD/index.png"              "$WEB/index.$HI.png"
cp "$BUILD/index.icon.png" "$BUILD/index.apple-touch-icon.png" "$WEB/"
gzip -9 -k -f "$WEB/index.$HW.wasm"
gzip -9 -k -f "$WEB/index.$HJ.js"

python3 - "$BUILD/index.html" "$WEB/index.html" "$HW" "$HP" "$HJ" "$HI" <<'PY'
import sys, re, json
src, dst, hw, hp, hj, hi = sys.argv[1:]
s = open(src, encoding="utf-8").read()
m = re.search(r"GODOT_CONFIG = (\{.*?\});", s)
cfg = json.loads(m.group(1))
sizes = cfg.get("fileSizes", {})
cfg["executable"] = "index.%s" % hw
cfg["mainPack"] = "index.%s.pck" % hp
cfg["fileSizes"] = {"index.%s.pck" % hp: sizes.get("index.pck", 0), "index.%s.wasm" % hw: sizes.get("index.wasm", 0)}
s = s[:m.start(1)] + json.dumps(cfg) + s[m.end(1):]
s = s.replace('src="index.js"', 'src="index.%s.js"' % hj).replace('src="index.png"', 'src="index.%s.png"' % hi)
open(dst, "w", encoding="utf-8").write(s)
PY

# drop hashed files from older deploys and the un-hashed originals
for f in "$WEB"/index.*; do
	b=$(basename "$f")
	case "$b" in
		index.$HW.*|index.$HP.*|index.$HJ.*|index.$HI.*|index.html|index.icon.png|index.apple-touch-icon.png) ;;
		*) rm -f "$f" ;;
	esac
done
echo "deployed to $WEB: wasm=$HW pck=$HP js=$HJ splash=$HI ($(du -h "$BUILD/index.pck" | cut -f1) pck)"
