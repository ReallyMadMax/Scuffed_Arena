extends Node

@export var PlayerScene : PackedScene

@onready var musicAudioStreamBG = $"AudioStreamPlayer-BGM"
@onready var HUD = $HUD
var backgroundMusicOn = true

@export var respawn_time : float = 3.0  # Time in seconds before respawn
@export var spawn_radius : float = 400.0  # Random spawn radius around spawn point

# Dictionary to track respawn timers: player_id -> Timer
var respawn_timers : Dictionary = {}
# Track when player died for instant respawn logic
var death_time : float = 0.0

func _perform_respawn(player_node: Node2D):
	"""Helper function to handle the actual respawn logic"""
	print("Performing respawn for player...")

	# Find a valid spawn position (not colliding with anything)
	var spawn_position = _find_valid_spawn_position(player_node)

	if spawn_position != Vector2.ZERO:
		player_node.global_position = spawn_position
		# Call respawn via RPC
		player_node.respawn.rpc()
		print("Player respawned at position: ", spawn_position)
	else:
		print("ERROR: Could not find valid spawn position")

func _on_client_spawn():
	# Called when player selects an upgrade
	print("_on_client_spawn called - respawning player...")

	# Use the client player from GameManager
	var player_node = GameManager.client_player
	if player_node and player_node.has_method("respawn"):
		# Check if 3 seconds have passed since death
		var time_since_death = Time.get_ticks_msec() / 1000.0 - death_time
		print("Time since death: ", time_since_death, " seconds")

		if time_since_death >= respawn_time:
			# Instant respawn
			print("Instant respawn (3+ seconds elapsed)")
			_perform_respawn(player_node)
		else:
			# Wait the remaining time before respawning
			var remaining_time = respawn_time - time_since_death
			print("Waiting ", remaining_time, " seconds before respawn")
			await get_tree().create_timer(remaining_time).timeout
			_perform_respawn(player_node)
	else:
		print("ERROR: Could not find client player to respawn!")

func _ready():
	print("Main scene _ready() called!")
	print("Main scene ready - GameManager.Players: ", GameManager.Players)
	GameManager.HUD = HUD

	# Connect to client_spawn signal to respawn after upgrade selection
	GameManager.client_spawn.connect(_on_client_spawn)

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

		# Connect death signal
		currentPlayer.player_died.connect(_on_player_died)
		GameManager.client_player = currentPlayer

		var spawn = get_tree().get_nodes_in_group("PlayerSpawnPoint").get(0)
		if spawn:
			currentPlayer.global_position = spawn.global_position
			print("Player spawned at: ", spawn.global_position)
		else:
			print("WARNING: No PlayerSpawnPoint found!")

func _process(_delta):
	update_music_stats()

func update_music_stats():
	if backgroundMusicOn:
		if !musicAudioStreamBG.playing:
			musicAudioStreamBG.play()
	else: 
		musicAudioStreamBG.stop()

func _on_player_died(player_id: int):
	GameManager._on_client_death()
	print("Main scene received death signal for player ", player_id)
	print("Player will respawn after selecting an upgrade")

	# Track death time for instant respawn logic
	death_time = Time.get_ticks_msec() / 1000.0

func _find_valid_spawn_position(player_node: Node2D) -> Vector2:
	var spawn_point = get_tree().get_nodes_in_group("PlayerSpawnPoint")
	if spawn_point.size() == 0:
		print("WARNING: No PlayerSpawnPoint found!")
		return Vector2.ZERO

	var base_spawn = spawn_point[0].global_position
	var space_state = player_node.get_world_2d().direct_space_state
	var max_attempts = 20  # Try 20 times to find a valid position

	# Get player's collision shape for testing
	var collision_shape = null
	for child in player_node.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break

	if not collision_shape:
		print("WARNING: Player has no CollisionShape2D, spawning without collision check")
		var random_offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		return base_spawn + random_offset

	# Try to find a position without collisions
	for attempt in range(max_attempts):
		var random_offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		var test_position = base_spawn + random_offset

		# Create a physics query
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = Transform2D(0, test_position)
		query.collision_mask = player_node.collision_mask
		query.exclude = [player_node.get_rid()]

		# Check for collisions
		var result = space_state.intersect_shape(query, 1)

		if result.size() == 0:
			# No collision, this position is valid!
			print("Found valid spawn position after ", attempt + 1, " attempts at ", test_position)
			return test_position

	# If we couldn't find a valid position, just spawn at base point
	print("WARNING: Could not find collision-free spawn after ", max_attempts, " attempts, using base spawn")
	return base_spawn
