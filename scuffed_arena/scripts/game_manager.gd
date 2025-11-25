extends Node

signal client_death
signal client_spawn

var client_player:Player
#this.Players[id] = { id: id, name: name };
var Players = {}

@onready var upgrade_menu_scene:PackedScene = load("res://scenes/gui/menus/upgrade_menu.tscn")
var HUD:CanvasLayer

# these should really be dictated by the specific game script incase the behaviour changes
# but for now i'll be lazy - fred
func _on_client_death():
	if not client_player or not HUD:
		return
	
	# show the upgrade menu
	var upgrade_menu = upgrade_menu_scene.instantiate()
	HUD.add_child(upgrade_menu)
	client_death.emit()

func spawn_client():
	client_spawn.emit()
var using_controller : bool = false

func _ready():
	# Start with cursor visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Detect controller input
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion:
			# Only consider it controller input if the axis moved significantly
			if abs(event.axis_value) > 0.2:
				if not using_controller:
					using_controller = true
					Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		else:
			if not using_controller:
				using_controller = true
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Detect mouse movement
	elif event is InputEventMouseMotion:
		if event.relative.length() > 0:
			if using_controller:
				using_controller = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
