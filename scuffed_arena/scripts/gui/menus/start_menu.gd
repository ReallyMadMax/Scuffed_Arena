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
