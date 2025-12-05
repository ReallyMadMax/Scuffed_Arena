extends CharacterBody2D

@export var speed : float = 500
@export var lifetime : float = 3.0  # Time in seconds before despawning
@export var damage : int = 50  # Damage dealt on hit
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var dir : float
var spawn_position : Vector2
var spawn_rotation : float
var shooter_id : int  # ID of the player who shot this projectile

var rotation_lerp_time : float = 0.3  # Time to lerp rotation
var rotation_timer : float = 0.0
var start_rotation : float
var target_rotation : float

func _init():
	scale = Vector2(0.25, 0.25)

func _ready():
	global_position = spawn_position

	# Set up rotation lerping
	# Apply -90 degree offset to both to compensate for sprite being drawn pointing up
	start_rotation = spawn_rotation - deg_to_rad(90)
	target_rotation = dir - deg_to_rad(90)

	# Ensure we take the shortest rotation path by normalizing the angle difference
	# This fixes the issue where shooting left would rotate the long way around
	var diff = fposmod(target_rotation - start_rotation + PI, TAU) - PI
	target_rotation = start_rotation + diff

	global_rotation = start_rotation

	# Start the spin animation
	animated_sprite.play("spin")

	# Enable collision for hitting players
	# Set appropriate collision layers based on your project setup
	collision_layer = 2  # Projectile layer
	collision_mask = 1   # Collides with player layer (adjust if needed)

	# Add collision exception for the shooter so the bullet passes through them
	var shooter = get_node("/root/Main/" + str(shooter_id))
	if shooter:
		add_collision_exception_with(shooter)

	# Create a timer to despawn after lifetime expires
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_timeout)
	add_child(timer)
	timer.start()


func _physics_process(_delta):
	# Lerp rotation over time
	if rotation_timer < rotation_lerp_time:
		rotation_timer += _delta
		var t = rotation_timer / rotation_lerp_time
		# Use smoothstep for a nicer easing
		t = t * t * (3.0 - 2.0 * t)
		global_rotation = lerp_angle(start_rotation, target_rotation, t)
	else:
		global_rotation = target_rotation

	velocity = Vector2(speed, 0).rotated(dir)
	animated_sprite.play("spin")
	move_and_slide()

	# Check for collisions after moving
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		# Check if we hit a player
		if collider is Player:
			# Don't damage the player who shot this projectile
			if collider.name != str(shooter_id):
				# Deal damage via RPC to work with multiplayer
				collider.take_damage.rpc(damage)
				queue_free()  # Despawn the projectile
				return

func _on_lifetime_timeout():
	queue_free()
