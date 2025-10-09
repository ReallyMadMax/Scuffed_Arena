@tool
extends player_class

# Enemy properties
@export var detection_range: float = 300.0
@export var stop_distance: float = 30.0

# Animation reference
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Player reference
var player: Node2D = null

func _init():
	speed = 150
	
func _ready():
	player = get_node("../Player")
	# Scale the enemy by 1.5x
	scale = Vector2(1.5, 1.5)

func _physics_process(_delta):
	if not Engine.is_editor_hint():
		if player == null:
			return
	   
		# Calculate distance to player
		var distance_to_player = global_position.distance_to(player.global_position)
	   
		# Check if player is within detection range
		if distance_to_player <= detection_range and distance_to_player > stop_distance:
			# Calculate direction to player
			direction = (player.global_position - global_position).normalized()
		   
			# Move towards player (speed is already in pixels per second)
			velocity = direction * speed
		   
			# Play walk animation
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
				
		elif distance_to_player <= stop_distance:
			# Stop moving and attack when close enough
			velocity = Vector2.ZERO
			
			# Play hit animation when within stop distance
			if animated_sprite.animation != "hit":
				animated_sprite.play("hit")
				
		else:
			# Stop moving if player is too far
			velocity = Vector2.ZERO
			
			# Play idle animation when player is out of range
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")  # Change to animated_sprite.stop() if no idle animation
	   
		# Handle sprite mirroring based on player position
		if player.global_position.x < global_position.x:
			animated_sprite.flip_h = true  # Mirror when player is to the left
		else:
			animated_sprite.flip_h = false  # Normal when player is to the right
	   
		# Apply movement
		move_and_slide()
