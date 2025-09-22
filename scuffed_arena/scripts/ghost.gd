extends CharacterBody2D

# Enemy properties
@export var speed: float = 100.0
@export var detection_range: float = 200.0
@export var stop_distance: float = 50.0

# Player reference
var player: Node2D = null

func _ready():
	player = get_node("../Player")

func _physics_process(_delta):
	if player == null:
		return
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if player is within detection range
	if distance_to_player <= detection_range and distance_to_player > stop_distance:
		# Calculate direction to player
		var direction = (player.global_position - global_position).normalized()
		
		# Move towards player (speed is already in pixels per second)
		velocity = direction * speed
		
		# Optional: Face the player (if you have sprites that need rotation)
		# look_at(player.global_position)
		
	else:
		# Stop moving if player is too far or too close
		velocity = Vector2.ZERO
	
	# Apply movement
	move_and_slide()

# Optional: Draw detection range in editor (for debugging)
func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, detection_range, Color.RED, false, 2.0)
		draw_circle(Vector2.ZERO, stop_distance, Color.YELLOW, false, 2.0)