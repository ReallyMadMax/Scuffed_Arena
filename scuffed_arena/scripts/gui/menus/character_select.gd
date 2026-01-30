extends Control

# Character data structure
class CharacterData:
	var id: String
	var name: String
	var description: String
	var scene_path: String
	var icon_path: String
	var stats: Dictionary

	func _init(p_id: String, p_name: String, p_desc: String, p_scene: String, p_icon: String, p_stats: Dictionary):
		id = p_id
		name = p_name
		description = p_desc
		scene_path = p_scene
		icon_path = p_icon
		stats = p_stats

# Available characters
var characters: Array[CharacterData] = []
var selected_character_id: String = ""
var ready_players: Dictionary = {}  # player_id -> bool

# UI References
@onready var character_grid = $MarginContainer/HBoxContainer/LeftPanel/VBoxContainer/CharacterGrid
@onready var character_name_label = $MarginContainer/HBoxContainer/RightPanel/TopPanel/VBoxContainer/CharacterName
@onready var character_description = $MarginContainer/HBoxContainer/RightPanel/TopPanel/VBoxContainer/Description
@onready var character_stats = $MarginContainer/HBoxContainer/RightPanel/TopPanel/VBoxContainer/Stats
@onready var ready_button = $MarginContainer/HBoxContainer/RightPanel/BottomPanel/VBoxContainer/ReadyButton
@onready var player_status_list = $MarginContainer/HBoxContainer/RightPanel/BottomPanel/VBoxContainer/PlayerStatusList

func _ready():
	# Initialize character data
	characters.append(CharacterData.new(
		"skele",
		"Skele - Ranged Mage",
		"A nimble skeleton mage who wields crystal magic. Fires projectiles from a distance but has lower defense.",
		"res://scenes/characters/Skele/player.tscn",
		"res://assets/images/skele_idle.PNG",
		{
			"Speed": "400",
			"Range": "Long",
			"Difficulty": "Medium"
		}
	))

	characters.append(CharacterData.new(
		"orc",
		"Orc - Melee Warrior",
		"A brutal orc warrior who excels at close combat. High health and damage, but slower movement.",
		"res://scenes/characters/orc.tscn",
		"res://assets/images/skele_idle.PNG",
		{
			"Speed": "300",
			"Range": "Melee",
			"Difficulty": "Easy"
		}
	))

	characters.append(CharacterData.new(
		"knight",
		"Knight - Tank",
		"A heavily armored knight with high defense. Slow but can absorb massive amounts of damage.",
		"res://scenes/characters/orc.tscn",
		"res://assets/images/skele_idle.PNG",
		{
			"Speed": "250",
			"Range": "Melee",
			"Difficulty": "Easy"
		}
	))

	# Create character selection buttons
	_create_character_buttons()

	# Initialize ready status for all players
	for player_id in GameManager.Players:
		ready_players[player_id] = false

	# Update player status display
	_update_player_status()

	# Set up multiplayer RPCs
	if multiplayer.is_server():
		# Host can start when all ready
		ready_button.text = "Start Game"

	# Select first character by default
	if characters.size() > 0:
		_select_character(characters[0].id)

func _create_character_buttons():
	# Clear existing buttons
	for child in character_grid.get_children():
		child.queue_free()

	# Create a button for each character
	for character in characters:
		var button = Button.new()
		button.custom_minimum_size = Vector2(200, 250)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.text = character.name.split(" - ")[0]  # Just the character name
		button.pressed.connect(_on_character_button_pressed.bind(character.id))

		# Try to load character icon
		if ResourceLoader.exists(character.icon_path):
			var texture = load(character.icon_path)
			if texture:
				button.icon = texture
				button.expand_icon = true
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

		character_grid.add_child(button)

func _on_character_button_pressed(character_id: String):
	_select_character(character_id)

func _select_character(character_id: String):
	selected_character_id = character_id

	# Find character data
	var character: CharacterData = null
	for c in characters:
		if c.id == character_id:
			character = c
			break

	if character == null:
		return

	# Update info display
	character_name_label.text = character.name
	character_description.text = character.description

	# Update stats display
	var stats_text = "Stats:\n"
	for stat_name in character.stats:
		stats_text += "  %s: %s\n" % [stat_name, character.stats[stat_name]]
	character_stats.text = stats_text

	# Highlight selected button
	_highlight_selected_button(character_id)

func _highlight_selected_button(character_id: String):
	var index = 0
	for character in characters:
		if index < character_grid.get_child_count():
			var button = character_grid.get_child(index)
			if character.id == character_id:
				button.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
			else:
				button.modulate = Color(1, 1, 1)  # Normal color
		index += 1

func _on_ready_button_pressed():
	if selected_character_id == "":
		print("No character selected!")
		return

	if multiplayer.is_server():
		# Host starts the game
		_start_game()
	else:
		# Client marks ready and sends to server
		_mark_ready()

func _mark_ready():
	var my_id = multiplayer.get_unique_id()
	ready_players[my_id] = true
	ready_button.disabled = true
	ready_button.text = "Ready!"

	# Notify server
	_notify_ready.rpc_id(1, my_id, selected_character_id)

	_update_player_status()

@rpc("any_peer", "call_remote", "reliable")
func _notify_ready(player_id: int, character_id: String):
	if multiplayer.is_server():
		print("Player %d is ready with character: %s" % [player_id, character_id])
		ready_players[player_id] = true

		# Store character selection in GameManager
		if str(player_id) in GameManager.Players:
			GameManager.Players[str(player_id)]["character"] = character_id

		# Broadcast ready status to all clients
		_update_ready_status.rpc(ready_players, GameManager.Players)

		# Check if all players are ready
		_check_all_ready()

@rpc("authority", "call_local", "reliable")
func _update_ready_status(new_ready_players: Dictionary, updated_players: Dictionary):
	ready_players = new_ready_players
	GameManager.Players = updated_players
	_update_player_status()

func _check_all_ready():
	if not multiplayer.is_server():
		return

	var all_ready = true
	for player_id in GameManager.Players:
		if not ready_players.get(player_id, false):
			all_ready = false
			break

	if all_ready and GameManager.Players.size() > 0:
		ready_button.disabled = false
		ready_button.text = "Start Game (All Ready!)"

func _start_game():
	if not multiplayer.is_server():
		return

	# Store host's character selection
	var my_id = multiplayer.get_unique_id()
	if str(my_id) in GameManager.Players:
		GameManager.Players[str(my_id)]["character"] = selected_character_id

	# Notify all clients to start
	_load_main_scene.rpc()

@rpc("authority", "call_local", "reliable")
func _load_main_scene():
	print("Loading main scene...")
	var scene = load("res://scenes/main.tscn").instantiate()

	# List of autoload singletons to keep
	var autoloads = ["GameManager", "UpgradeManager", "Client"]

	for child in get_tree().root.get_children():
		if child.name not in autoloads:
			child.queue_free()

	get_tree().root.add_child(scene)

func _update_player_status():
	var status_text = "Players:\n"
	for player_id in GameManager.Players:
		var player_name = GameManager.Players[player_id].get("name", "Player " + str(player_id))
		var is_ready = ready_players.get(player_id, false)
		var ready_status = "✓ Ready" if is_ready else "Waiting..."
		var character = GameManager.Players[player_id].get("character", "Not selected")
		status_text += "%s - %s (%s)\n" % [player_name, character, ready_status]

	player_status_list.text = status_text
