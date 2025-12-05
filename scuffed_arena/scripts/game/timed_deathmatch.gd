extends GameMode

@export var game_duration:int = 120
@export var respawn_duration:int = 5

var game_timer:Timer

func _ready() -> void:
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.timeout.connect(_game_over)
	game_timer.start(game_duration)

# show the upgrade menu scree
func on_player_death(player_id:int):
	if GameManager.client_player.id == player_id:
		# show the upgrade menu
		HUD.show_upgrade_menu()
		# start the respawn timer
		# we might want to make this visible later
		var respawn_timer:Timer = Timer.new()
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(on_player_spawn, player_id)
		respawn_timer.start(respawn_duration)

func on_player_spawn(player_id:int):
	super.on_player_spawn(player_id)
	
	HUD.hide_upgrade_menu()
