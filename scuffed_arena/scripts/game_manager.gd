extends Node

signal client_death
signal client_spawn

var client_player:Player
#this.Players[id] = { id: id, name: name };
var Players = {}

@onready var upgrade_menu_scene:PackedScene = load("res://scenes/gui/menus/upgrade_menu.tscn")

# these should really be dictated by the specific game script incase the behaviour changes
# but for now i'll be lazy - fred
func _on_client_death():
	if not client_player:
		return
	
	# show the upgrade menu
	var upgrade_menu = upgrade_menu_scene.instantiate()
	get_tree().root.add_child(upgrade_menu)
	client_death.emit()

func spawn_client():
	client_spawn.emit()
