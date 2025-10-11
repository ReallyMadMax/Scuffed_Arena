extends RefCounted
class_name Lobby

var HostId : int
var Players : Dictionary = {}

func _init(id:int):
	HostId = id

func add_player(id:int, player_name:String):
	Players[id] = {
		"name" : player_name,
		"id" : id,
		"index" : Players.size(),
	}
	return Players[id]
