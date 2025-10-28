extends Node

@export var PlayerScene : PackedScene

@onready var musicAudioStreamBG = $"AudioStreamPlayer2D-BGM"
var backgroundMusicOn = true


func _ready():
	print("Main scene _ready() called!")
	print("Main scene ready - GameManager.Players: ", GameManager.Players)

	# Load player scene if not set in inspector
	if PlayerScene == null:
		print("PlayerScene not set in inspector, loading manually...")
		PlayerScene = load("res://scenes/player.tscn")

	print("PlayerScene: ", PlayerScene)

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

func _process(delta):
	update_music_status()

func update_music_status()
	if backgroundMusicOn:
		if !musicAudioStreamBG.playing
			musicAudioStream.play()
	else: 
		musicAudioStreamBG.stop()
		