extends Node
## Repro: collect all 7, then operate the Vaccine Synthesizer; verify it upgrades
## and sets mrna_assembled (which unlocks the door).

func _ready() -> void:
	var lab = load("res://scenes/world/Laboratory.tscn").instantiate()
	add_child(lab)
	for i in 6:
		await get_tree().process_frame
	# find pickups and synth
	var pickups: Array = []
	var synth = null
	_scan(lab, pickups, [])
	synth = _find_synth(lab)
	print("SYNTH: pickups=", pickups.size(), " synth=", synth != null)
	# collect all
	for pk in pickups:
		if not is_instance_valid(pk): continue
		pk.interact()
		var g = 0
		while DialogueManager.is_active() and g < 30:
			DialogueManager.advance(); await get_tree().process_frame; g += 1
		for i in 3: await get_tree().process_frame
	print("SYNTH: has_all=", Inventory.has_all_mrna())
	# let the checker run
	for i in 10: await get_tree().process_frame
	print("SYNTH: synth.lines_count=", (synth.lines.size() if synth else -1), " on_finished=", (synth.on_finished_flag if synth else "?"))
	# operate synth
	if synth:
		synth.interact()
		var g = 0
		while DialogueManager.is_active() and g < 30:
			DialogueManager.advance(); await get_tree().process_frame; g += 1
		for i in 5: await get_tree().process_frame
	print("SYNTH: mrna_assembled=", GameState.has_flag("mrna_assembled"))
	print("SYNTH: DONE")
	get_tree().quit()

func _scan(n: Node, pickups: Array, _x: Array) -> void:
	if "component_id" in n and n.has_method("interact"):
		pickups.append(n)
	for c in n.get_children():
		_scan(c, pickups, _x)

func _find_synth(n: Node):
	if n.has_method("_missing_names"):
		return n
	for c in n.get_children():
		var r = _find_synth(c)
		if r: return r
	return null
