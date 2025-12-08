extends GameMode
class_name TimedDeathmatch

@export var game_duration:int = 120
@export var respawn_duration:int = 5

var game_timer:Timer

func _ready() -> void:
	game_timer = Timer.new()
	GameManager.add_child(game_timer)
	game_timer.one_shot = true
	game_timer.timeout.connect(_game_over)
	game_timer.start(game_duration)
	
	# this will be handled with the resource group once there are more maps
	var map_scene:PackedScene = load("res://scenes/map.tscn")
	active_map = map_scene.instantiate()
	GameManager.add_child(active_map)

# show the upgrade menu scree
func on_player_death(player_id:int):
	if GameManager.client_id == player_id:
		# start the respawn timer
		var respawn_timer:Timer = Timer.new()
		GameManager.add_child(respawn_timer)
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(on_player_spawn.bind(player_id))
		respawn_timer.start(respawn_duration)
		
		# show the upgrade menu
		HUD.show_menu(HUD.menu.UPGRADE_MENU)
		HUD.loaded_menus[HUD.menu.UPGRADE_MENU].reset()
		HUD.loaded_menus[HUD.menu.UPGRADE_MENU].upgrade_timer = respawn_timer

func on_player_spawn(player_id:int):
	if GameManager.client_id == player_id:
		GameManager.Players[player_id].respawn.rpc(active_map.get_spawn_position())
		HUD.hide_menu(HUD.menu.UPGRADE_MENU)
