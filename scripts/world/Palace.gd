extends LevelBase
## Chapter 2 — The Princess's Chamber. Arin finds Mira, learns she has cancer,
## and discovers the mRNA scroll that begins the scientific quest.

func _ready() -> void:
	chapter_id = "palace"
	room_size = Vector2(1200, 1900)
	floor_texture = preload("res://assets/env/floor_palace.png")
	wall_texture = preload("res://assets/env/wall_palace.png")
	default_spawn = Vector2(600, 1700)
	super._ready()

func build_content() -> void:
	# Princess Mira, resting.
	add_npc(Vector2(600, 700), "Princess Mira",
		[
			["Mira", "Arin... you came. But I am gravely ill. The healers call it cancer."],
			["Arin", "I will not lose you. There must be a cure."],
			["Mira", "On the pedestal... an ancient scroll. It speaks of a strange medicine."],
		],
		"res://assets/characters/mira_hd.png", "met_mira")

	# The mRNA scroll — sets the quest flag when read.
	var scroll := add_npc(Vector2(600, 450), "The Healer's Scroll",
		[
			["Scroll", "Your body already has an army, but it cannot see the cancer. Send it a Royal Letter that shows the enemy's face."],
			["Scroll", "A letter needs seven parts, scattered across the Molecular Kingdom: a seal, a greeting, a wanted poster, a fuse... Find them all."],
			["Scroll", "Put the parts in the right order, wrap the letter in a shield, and deliver it inside her body."],
			["Scroll", "This is no fairy tale. Since 2020, letters just like this one have been used in COVID-19 vaccines given to hundreds of millions of people."],
			["Arin", "Then to the molecular kingdom I go. Hold on, Mira."],
		],
		"res://assets/env/scroll.png", "read_scroll")
	scroll.on_finished_flag = "quest_started"

	# Door to the laboratory — opens only after reading the scroll.
	var door := add_portal(Vector2(600, 120), "laboratory", "To the Molecular Kingdom", Vector2(700, 1250))
	door.required_flag = "quest_started"
