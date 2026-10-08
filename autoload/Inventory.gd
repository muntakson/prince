extends Node
## Tracks the mRNA molecular components the player has collected.
## Autoloaded as "Inventory".

signal item_collected(id: String)
signal inventory_changed()

## The canonical mRNA build order (5' -> 3'). Also the correct answer for the
## "assemble mRNA" mini-game. Each entry maps to a sprite in assets/molecules/.
const MRNA_ORDER: Array[String] = [
	"cap5",         # 5' cap
	"utr5",         # 5' UTR
	"start_codon",  # start codon (AUG)
	"orf",          # antigen-coding open reading frame
	"stop_codon",   # stop codon
	"utr3",         # 3' UTR
	"polya",        # poly(A) tail
]

## Human-readable metadata for HUD / dialogue / mini-games.
const COMPONENTS := {
	"cap5":        {"name": "5′ Cap",        "blurb": "Protects the mRNA and helps ribosomes find the start."},
	"utr5":        {"name": "5′ UTR",        "blurb": "Untranslated region that tunes how efficiently mRNA is read."},
	"start_codon": {"name": "Start Codon",   "blurb": "AUG — where translation begins."},
	"orf":         {"name": "Antigen ORF",   "blurb": "Open reading frame coding the tumor antigen."},
	"stop_codon":  {"name": "Stop Codon",    "blurb": "Signals the ribosome to release the finished protein."},
	"utr3":        {"name": "3′ UTR",        "blurb": "Untranslated region controlling mRNA stability."},
	"polya":       {"name": "Poly(A) Tail",  "blurb": "A tail of adenines that stabilizes the mRNA."},
	"lnp":         {"name": "Lipid Nanoparticle", "blurb": "Delivery vehicle that protects and carries the mRNA."},
	"antibody":    {"name": "Antibody",      "blurb": "Immune protein that recognizes the presented antigen."},
	"ribosome":    {"name": "Ribosome",      "blurb": "Molecular machine that reads mRNA into protein."},
}

var collected: Dictionary = {}   # id -> true

func collect(id: String) -> bool:
	if collected.has(id):
		return false
	collected[id] = true
	item_collected.emit(id)
	inventory_changed.emit()
	return true

func has(id: String) -> bool:
	return collected.has(id)

func count_mrna() -> int:
	var n := 0
	for id in MRNA_ORDER:
		if collected.has(id):
			n += 1
	return n

func has_all_mrna() -> bool:
	return count_mrna() == MRNA_ORDER.size()

## The name players see: the kingdom nickname (Glossary) in the current
## language. The science name is earned on the Word Card.
func component_name(id: String) -> String:
	if Glossary.has(id):
		return Glossary.nick(id)
	return COMPONENTS.get(id, {}).get("name", id)

func science_name(id: String) -> String:
	if Glossary.has(id):
		return Glossary.sci(id)
	return COMPONENTS.get(id, {}).get("name", id)

func component_blurb(id: String) -> String:
	return COMPONENTS.get(id, {}).get("blurb", "")

func sprite_path(id: String) -> String:
	return "res://assets/molecules/%s.png" % id

func clear() -> void:
	collected.clear()
	inventory_changed.emit()

## --- serialization ---
func to_dict() -> Dictionary:
	return {"collected": collected}

func from_dict(d: Dictionary) -> void:
	collected = d.get("collected", {})
	inventory_changed.emit()
