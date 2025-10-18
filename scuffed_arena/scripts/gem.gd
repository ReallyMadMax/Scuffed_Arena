extends CharacterBody2D

@export var speed : float = 500
@export var lifetime : float = 3.0  # Time in seconds before despawning
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var dir : float
var spawn_position : Vector2
var spawn_rotation : float

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
    global_rotation = start_rotation

    # Disable collision
    collision_layer = 0
    collision_mask = 0

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

func _on_lifetime_timeout():
    queue_free()