extends Node
# the components will tell the game manager what happened
# the game manager will tell the game mode what happened which decides what to do

var client_id:int
#this.Players[id] = player: Player;
var Players:Dictionary = {}

var game_mode:GameMode:
	set(_mode):
		game_mode = _mode
		game_mode.game_over.connect(_on_game_over)

@rpc("any_peer", "call_local")
func add_player(player_id:int, player_name:String, _character) -> void:
	var player_scene:PackedScene = load("res://scenes/player.tscn")
	var player:Player = player_scene.instantiate()
	Players[player_id] = player
	player.name = player_name
	player.id = player_id
	player.player_died.connect(_on_player_death)
	
	player.set_multiplayer_authority(player_id)
	
	add_child(Players[player_id])

@rpc("any_peer", "call_local")
func start_game():
	HUD.clear_menus()
	
	if not game_mode:
		game_mode = load("res://resources/game_modes/timed_deathmatch.tres")
	game_mode._ready()
	
	for player_id:int in Players.keys():
		game_mode.on_player_spawn(player_id)

func _on_player_death(player_id:int):
	game_mode.on_player_death(player_id)

func _on_game_over():
	var winner_id = game_mode.get_winner()
	print("Player " + str(winner_id) + " won")
