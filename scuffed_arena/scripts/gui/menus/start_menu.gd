extends Control

@onready var host_button = $"HBoxContainer/Host Game"
@onready var join_button = $"HBoxContainer/Join Game"

func _ready():
	# Set initial focus for controller navigation
	host_button.grab_focus()

func _on_host_game_button_down() -> void:
	var scene = load("res://scenes/gui/menus/host_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()


func _on_join_game_button_down() -> void:
	var scene = load("res://scenes/gui/menus/connect_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()


func _on_testing_mode_pressed() -> void:
	# Create a basic multiplayer peer for testing (host mode)
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(6000)  # Port doesn't matter for local testing
	multiplayer.multiplayer_peer = peer

	# Use the actual multiplayer unique ID (will be 1 for host)
	var id = multiplayer.get_unique_id()
	var player_name = "test"
	GameManager.Players[str(id)] = {
		"id": id,
		"name": player_name
	};
	Client.start_game()
