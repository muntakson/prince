extends Node
## Repro: collect all Laboratory pickups and watch for freed-instance errors / stuck pause.

func _ready() -> void:
	var lab = load("res://scenes/world/Laboratory.tscn").instantiate()
	add_child(lab)
	for i in 5:
		await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	var pickups: Array = []
	_collect_pickups(lab, pickups)
	print("REPRO: pickups=", pickups.size())
	for pk in pickups:
		if not is_instance_valid(pk):
			continue
		var cid = pk.component_id
		# place player on the pickup so its InteractArea overlaps
		player.global_position = pk.global_position
		for i in 4:
			await get_tree().physics_frame
		# collect
		pk.interact()
		# drain dialogue
		var guard = 0
		while DialogueManager.is_active() and guard < 40:
			DialogueManager.advance()
			await get_tree().process_frame
			guard += 1
		# let the collect tween free the pickup, and run player physics each frame
		for i in 30:
			await get_tree().process_frame
		print("REPRO: collected=", cid, " paused=", get_tree().paused, " has_all=", Inventory.has_all_mrna())
	# extra frames to trip any freed-ref access in _update_interactable
	for i in 40:
		await get_tree().process_frame
	print("REPRO: FINAL paused=", get_tree().paused, " has_all=", Inventory.has_all_mrna(), " mrna_flag=", GameState.has_flag("mrna_assembled"))
	print("REPRO: DONE")
	get_tree().quit()

func _collect_pickups(n: Node, out: Array) -> void:
	if n.get_script() and n.has_method("interact") and "component_id" in n:
		out.append(n)
	for c in n.get_children():
		_collect_pickups(c, out)
