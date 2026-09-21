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
	var scroll := add_npc(Vector2(600, 450), "The mRNA Scroll",
		[
			["Scroll", "To teach the body to fight the illness, craft an mRNA — a message of life."],
			["Scroll", "Gather its seven parts: 5′ cap, 5′ UTR, start codon, the antigen code, stop codon, 3′ UTR, and poly(A) tail."],
			["Scroll", "Assemble them, wrap them in a lipid shield, and deliver the message within."],
			["Arin", "Then to the molecular kingdom I go. Hold on, Mira."],
		],
		"res://assets/env/scroll.png", "read_scroll")
	scroll.on_finished_flag = "quest_started"

	# Door to the laboratory — opens only after reading the scroll.
	var door := add_portal(Vector2(600, 120), "laboratory", "To the Molecular Kingdom", Vector2(700, 1250))
	door.required_flag = "quest_started"
