extends Node
# the components will tell the game manager what happened
# the game manager will tell the game mode what happened which decides what to do

signal client_death
signal client_spawn

var client_player:Player
#this.Players[id] = { id: id, name: name };
var Players = {}

@onready var upgrade_menu_scene:PackedScene = load("res://scenes/gui/menus/upgrade_menu.tscn")
var HUD:CanvasLayer
var game_mode:GameMode:
	set(_mode):
		game_mode = _mode
		game_mode.game_over.connect(_on_game_over)

# these should really be dictated by the specific game script incase the behaviour changes
# but for now i'll be lazy - fred
func _on_player_death(player_id:int):
	game_mode.on_player_death(player_id)
	if not client_player or not HUD:
		return
	
	# show the upgrade menu
	var upgrade_menu = upgrade_menu_scene.instantiate()
	HUD.add_child(upgrade_menu)
	client_death.emit()

func spawn_client():
	client_spawn.emit()

func _on_game_over():
	var winner_id = game_mode.get_winner()
	print("Player " + str(winner_id) + " won")
