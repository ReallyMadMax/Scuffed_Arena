@abstract
extends Resource
class_name GameMode

signal game_over

# group of all the maps that can be played in this mode
var available_maps:ResourceGroup
var winner_id:int
var active_map:Map

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
@abstract
func on_player_spawn(player_id:int) -> void
