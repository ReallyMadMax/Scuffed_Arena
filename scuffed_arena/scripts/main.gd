extends Node
class_name Main

@export var PlayerScene : PackedScene
@export var SwordScene1 : PackedScene
@export var SwordScene2 : PackedScene
var rand = RandomNumberGenerator.new()
#var timer = Timer.new()
#var spawnrate = 50

func _ready():
	#add_child(timer)
	#timer.start(1)
	print("Main scene _ready() called!")
	print("Main scene ready - GameManager.Players: ", GameManager.Players)

	# Load player scene if not set in inspector
	if PlayerScene == null:
		print("PlayerScene not set in inspector, loading manually...")
		PlayerScene = load("res://scenes/player.tscn")

	print("PlayerScene: ", PlayerScene)

	if SwordScene1 == null:
		print("SwordScene not set in inspector, loading manually...")
		SwordScene1 = load("res://Inventory/Items/Item1/sword_1.tscn")
		print("SwordScene: ", SwordScene1)
	if SwordScene2 == null:
		print("SwordScene not set in inspector, loading manually...")
		SwordScene2 = load("res://Inventory/Items/Item 2/sword_2.tscn")
		for i in range(10):
			var randomsw1 = SwordScene1.instantiate()
			var randomsw2 = SwordScene2.instantiate()
			var x1 = rand.randf_range(0, 1200)
			var y1 = rand.randf_range(0, 650)
			randomsw1.position = Vector2(x1, y1)
			add_child(randomsw1)
			var x2 = rand.randf_range(0, 1200)
			var y2 = rand.randf_range(0, 650)
			randomsw2.position = Vector2(x2, y2)
			add_child(randomsw2)
	
	for i in GameManager.Players:
		var player_id = int(GameManager.Players[i].id)
		print("Spawning player with ID: ", player_id)
		var currentPlayer = PlayerScene.instantiate()
		currentPlayer.name = str(player_id)
		print("Player node name set to: ", currentPlayer.name)
		add_child(currentPlayer)
		var spawn = get_tree().get_nodes_in_group("PlayerSpawnPoint").get(0)
		if spawn:
			currentPlayer.global_position = spawn.global_position
			print("Player spawned at: ", spawn.global_position)
		else:
			print("WARNING: No PlayerSpawnPoint found!")
