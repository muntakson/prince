"""Stage backdrops for the Prince of mRNA play, one 1:2 (1.2 m x 2.4 m, portrait) PNG per scene.
Uses the Gemini image model (nano banana) through the REST API.

   GEMINI_API_KEY=<key> python3 tools/play/gen_backdrops.py            # all six
   GEMINI_API_KEY=<key> python3 tools/play/gen_backdrops.py 3 4        # only scenes 3 and 4
   GEMINI_MODEL=gemini-3-pro-image-preview GEMINI_IMAGE_SIZE=2K ...    # optional: a higher-resolution model

Output: play/backdrops/<nn>_<name>.png (cropped to 1:2) and play/backdrops/<nn>_<name>_raw.png (9:16 as generated).
Reference images in play/images/ are sent along with each prompt as style/anatomy references (REF_DIR, SCENES[n][2]).
Existing files are skipped; delete one to regenerate it.
"""
import base64, io, json, os, sys, time, urllib.request
from PIL import Image

KEY = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
if not KEY:
    sys.exit("set GEMINI_API_KEY (or GOOGLE_API_KEY)")
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-image")
IMAGE_SIZE = os.environ.get("GEMINI_IMAGE_SIZE")  # "1K" / "2K" / "4K" on models that support it
OUT = "play/backdrops"; os.makedirs(OUT, exist_ok=True)

STYLE = ("Photorealistic 3D biomedical animation render, the look of a high-end medical visualization: "
         "physically based materials, subsurface scattering on membranes, volumetric light, shallow depth of field, "
         "accurate molecular and cellular anatomy drawn with care. Tall vertical portrait composition for a 1.2 m x 2.4 m "
         "stage backdrop panel. The lowest fifth of the picture is a calm, dark, uncluttered floor zone so live actors can "
         "stand in front of it. No people, no cartoon characters, no faces, no text, no labels, no arrows, no watermark.")

REF_DIR = "play/images"
SCENES = {
 1: ("princess_room",
     "A sick princess's bedchamber at night rendered as a modern medical-drama set: an empty canopy bed with white sheets "
     "under soft moonlight from a tall window, and in the air above the bed a large translucent anatomical hologram of a "
     "human torso showing a glowing tumour mass inside the lung and liver, with a microscopic inset of irregular cancer "
     "cells dividing uncontrollably (mitotic figures, large dark nuclei) and spreading along a blood vessel. Mood: quiet, "
     "sorrowful, clinical blue-violet light.",
     ["tcell.jpg"]),
 2: ("scroll_room",
     "A scholar's chamber turned molecular biology atlas: on a stone pedestal lies an unrolled luminous scroll, and rising "
     "out of it as a 3D hologram is the full anatomy of an mRNA vaccine molecule drawn accurately and large: a single RNA "
     "strand with a 5' cap at one end, the untranslated regions, a long coding region, and a long poly(A) tail of beads at "
     "the other end, with small glowing modified nucleosides along the strand. Behind it the central dogma as objects: a DNA "
     "double helix inside a nucleus, an RNA polymerase, and a ribosome (large and small subunit) threading the strand and "
     "extruding a folding protein chain. Warm golden light, bookshelves blurred in the background. Absolutely no words, "
     "letters or labels anywhere in the picture.",
     []),
 3: ("molecular_kingdom_lab",
     "The inside of a microfluidic LNP-formulation chip, seen at microscale: a glass channel with staggered herringbone "
     "grooves where an amber ethanol stream carrying lipids and a pink acidic aqueous stream carrying mRNA fold into each "
     "other and self-assemble into lipid nanoparticles. Show the assembly in stages along the channel: free ionizable "
     "lipids, cholesterol, DSPC and PEG-lipids with their hydrophilic heads and tails, then mRNA strands being wrapped by "
     "charged lipid, then finished ~80 nm spherical lipid nanoparticles with a translucent lipid shell and a coiled golden "
     "mRNA inside, like the reference. Teal and copper colour palette, laboratory glass and steel edges.",
     ["lnp1.png", "lnp2.png"]),
 4: ("inside_dendritic_cell",
     "The cytoplasm of a dendritic cell at nanoscale, like a medical animation: on the left a lipid nanoparticle being "
     "engulfed by the cell membrane (a clearly rendered phospholipid bilayer of bead-headed lipids) into an endosome, with "
     "a second endosome further in that is acidifying and whose membrane is being disrupted by the charged ionizable lipids, "
     "releasing a golden mRNA strand into the cytosol; in the centre a large ribosome reading that strand and extruding a "
     "growing amino-acid chain; around them mitochondria, rough endoplasmic reticulum, a Golgi stack, vesicles and "
     "cytoskeleton filaments; near the top the cell surface with MHC class I molecules presenting small peptides. Warm amber "
     "and teal lighting with volumetric depth.",
     ["cell_inside.png", "lnp3.png"]),
 5: ("lymph_node",
     "Inside a lymph node T-cell zone at cellular scale: a mature dendritic cell with long branching dendrites in the centre, "
     "its surface studded with MHC-peptide complexes, CD80/CD86 costimulatory molecules and secreted IL-12 droplets, forming an "
     "immunological synapse with one naive T cell whose T-cell receptors (Y-shaped TCR with CD3) and CD28 dock onto it; around "
     "them dozens of other round naive T cells with slightly different receptors drifting in lymph, held by a lattice of "
     "reticular fibres and high endothelial venules. Soft yellow-white light on a dark background, realistic cell textures; "
     "the bottom of the picture is a dark floor, never white.",
     []),
 6: ("tumor",
     "A tumour microenvironment at cellular scale: a mound of irregular dark tumour cells with large nuclei, some displaying "
     "PD-L1 molecules on their surface, being attacked by cytotoxic CD8 T cells that press against them and release perforin "
     "pores and granzyme granules so that one tumour cell blebs and bursts apart in apoptosis; a regulatory T cell exhaling a "
     "purple haze of IL-10 and TGF-beta; cancer-associated fibroblasts laying down thick collagen fibre walls with narrow gaps; "
     "a leaky blood vessel with red blood cells; bluish hypoxic shadows at the edges and a red glow at the core. Dramatic, "
     "cinematic, scientifically detailed.",
     ["tcell.jpg", "lnp3.png"]),
}

def generate(prompt, refs=()):
    parts = []
    for r in refs:
        rp = os.path.join(REF_DIR, r)
        if os.path.exists(rp):
            mime = "image/jpeg" if rp.lower().endswith((".jpg", ".jpeg")) else "image/png"
            parts.append({"inlineData": {"mimeType": mime, "data": base64.b64encode(open(rp, "rb").read()).decode()}})
    if parts:
        prompt = ("Use the attached pictures only as STYLE and ANATOMY references (rendering quality, membrane and "
                  "nanoparticle look, organelle shapes). Do not copy their layout and do not include their text labels. ") + prompt
    parts.append({"text": prompt})
    body = {"contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "9:16"}}}
    if IMAGE_SIZE: body["generationConfig"]["imageConfig"]["imageSize"] = IMAGE_SIZE
    url = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % MODEL
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        res = json.load(r)
    for part in res["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            return base64.b64decode(part["inlineData"]["data"])
    raise RuntimeError("no image in response: %s" % json.dumps(res)[:300])

def crop_1_2(png_bytes):
    im = Image.open(io.BytesIO(png_bytes)).convert("RGB")
    w, h = im.size
    tw = h // 2  # target width for 1:2
    if tw < w:
        x0 = (w - tw) // 2; im = im.crop((x0, 0, x0 + tw, h))
    else:
        th = w * 2; y0 = (h - th) // 2; im = im.crop((0, y0, w, y0 + th))
    return im

wanted = [int(a) for a in sys.argv[1:]] or sorted(SCENES)
manifest = {}
for n in wanted:
    name, desc, refs = SCENES[n]
    final = "%s/%02d_%s.png" % (OUT, n, name); raw = "%s/%02d_%s_raw.png" % (OUT, n, name)
    manifest[n] = {"file": final, "prompt": desc}
    if os.path.exists(final) and os.path.getsize(final) > 10000:
        print("skip", final); continue
    prompt = desc + " " + STYLE
    for attempt in range(3):
        try:
            data = generate(prompt, refs)
            open(raw, "wb").write(data)
            im = crop_1_2(data); im.save(final)
            print("ok", final, im.size, flush=True); break
        except urllib.error.HTTPError as e:
            msg = e.read()[:300]; print("HTTP", e.code, name, msg, flush=True)
            if e.code in (429, 503): time.sleep(10 * (attempt + 1)); continue
            break
        except Exception as e:
            print("ERR", name, e, flush=True); time.sleep(5)
json.dump(manifest, open(OUT + "/manifest.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
