@abstract
extends Node
class_name GameMode

signal game_over
signal spawn_player(player_id:int)

# group of all the maps that can be played in this mode
var available_maps:ResourceGroup
var winner_id:int

func _game_over():
	set_winner()
	game_over.emit()

# give players any extra data that they need
# ie lives, points, KDA, etc.
func wrap_player():
	pass
 
func set_winner():
	pass

func get_winner() -> int:
	return 0

@abstract
func on_player_death(player_id:int)

# will have to delegate the spawn points to the map script
func on_player_spawn(player_id:int):
	spawn_player.emit(player_id)
