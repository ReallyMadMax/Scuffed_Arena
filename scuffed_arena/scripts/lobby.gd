extends RefCounted
class_name Lobby

var id : int
var Players : Dictionary = {}

func _init(_id:int):
	id = _id

func add_player(player_id:int, player_name:String):
	Players[player_id] = {
		"name" : player_name,
		"id" : player_id,
	}
	return Players[id]

func remove_player(player_id:int):
	Players.erase(player_id)
