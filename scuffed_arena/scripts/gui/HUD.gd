extends Node

var hud_layer:CanvasLayer

@onready var upgrade_menu_scene:PackedScene = preload("res://scenes/gui/menus/upgrade_menu.tscn")
var upgrade_menu:Node

func _ready() -> void:
	hud_layer = CanvasLayer.new()
	get_tree().root.add_child(hud_layer)

func show(node:Node) -> void:
	hud_layer.add_child(node)

func hide(node:Node) -> void:
	hud_layer.remove_child(node)

func show_upgrade_menu() -> void:
	upgrade_menu = upgrade_menu_scene.instantiate()
	show(upgrade_menu)

func hide_upgrade_menu() -> void:
	hide(upgrade_menu)
	upgrade_menu.queue_free()
