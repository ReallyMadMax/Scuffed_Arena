extends Node

enum menu {
	UPGRADE_MENU,
	START_MENU,
	HOST_MENU,
	CONNECT_MENU,
	CHARACTER_SELECT_MENU,
}

var hud_layer:CanvasLayer

var menu_scenes:Dictionary
var loaded_menus:Dictionary

func _ready() -> void:
	hud_layer = CanvasLayer.new()
	get_tree().root.add_child.call_deferred(hud_layer)
	
	menu_scenes = {
		menu.UPGRADE_MENU : load("res://scenes/gui/menus/upgrade_menu.tscn"),
		menu.START_MENU : load("res://scenes/gui/menus/start_menu.tscn"),
		menu.CONNECT_MENU : load("res://scenes/gui/menus/connect_menu.tscn"),
		menu.HOST_MENU : load("res://scenes/gui/menus/host_menu.tscn"),
		menu.CHARACTER_SELECT_MENU : load("res://scenes/gui/menus/character_select_menu.tscn"),
	}

func show_menu(_menu:menu) -> void:
	if !loaded_menus.has(_menu):
		var node:Node = make_and_show(menu_scenes[_menu])
		loaded_menus[_menu] = node
	else:
		show(loaded_menus[_menu])

func hide_menu(_menu:menu) -> void:
	if loaded_menus.has(_menu):
		hide(loaded_menus[_menu])

func clear_menus() -> void:
	for scene:Node in loaded_menus.values():
		hide(scene)
		scene.queue_free()
	loaded_menus.clear()

func show(node:Node) -> void:
	if not node.get_parent():
		hud_layer.add_child(node)
	else:
		node.show()

func hide(node:Node) -> void:
	hud_layer.remove_child(node)

func make_and_show(scene:PackedScene) -> Node:
	var node:Node = scene.instantiate()
	show(node)
	return node

func hide_and_remove(node:Node) -> void:
	hide(node)
	node.queue_free()
