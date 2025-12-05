extends Node

signal game_over

@export var PlayerScene : PackedScene

@onready var musicAudioStreamBG = $"AudioStreamPlayer-BGM"
@onready var HUD = $HUD
var backgroundMusicOn = true

@export var game_time : float = 120 # Time in seconds before the game ends
@export var respawn_time : float = 3.0  # Time in seconds before respawn
@export var spawn_radius : float = 400.0  # Random spawn radius around spawn point

# Dictionary to track respawn timers: player_id -> Timer
var respawn_timers : Dictionary = {}

func _ready():
	# Start the game time
	var game_over_timer:Timer = Timer.new()
	game_over_timer.timeout.connect(game_over.emit)
	game_over_timer.start(game_time)
	
	GameManager.HUD = HUD

	# Load player scene if not set in inspector
	if PlayerScene == null:
		PlayerScene = load("res://scenes/player.tscn")

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

	# Clean up any existing timer for this player
	if respawn_timers.has(player_id):
		respawn_timers[player_id].queue_free()
		respawn_timers.erase(player_id)

	# Create new respawn timer
	var timer = Timer.new()
	timer.wait_time = respawn_time
	timer.one_shot = true
	timer.timeout.connect(_on_respawn_timer_timeout.bind(player_id))
	add_child(timer)
	respawn_timers[player_id] = timer
	timer.start()

	print("Started respawn timer for player ", player_id, " - respawning in ", respawn_time, " seconds")

func _on_respawn_timer_timeout(player_id: int):
	print("Respawn timer expired for player ", player_id, ", calling respawn...")

	# Find the player node
	var player_node = get_node_or_null(str(player_id))
	if player_node and player_node.has_method("respawn"):
		# Find a valid spawn position (not colliding with anything)
		var spawn_position = _find_valid_spawn_position(player_node)

		if spawn_position != Vector2.ZERO:
			player_node.global_position = spawn_position
			# Call respawn via RPC
			player_node.respawn.rpc()
		else:
			print("ERROR: Could not find valid spawn position for player ", player_id)
	else:
		print("ERROR: Could not find player node ", player_id, " to respawn!")

	# Clean up timer
	if respawn_timers.has(player_id):
		respawn_timers[player_id].queue_free()
		respawn_timers.erase(player_id)

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
