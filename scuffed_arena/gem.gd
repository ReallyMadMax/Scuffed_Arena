extends CharacterBody2D

@export var speed : float = 500
@export var lifetime : float = 3.0  # Time in seconds before despawning
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var dir : float
var spawn_position : Vector2
var spawn_rotation : float

func _init():
    scale = Vector2(0.25, 0.25)

func _ready():
    global_position = spawn_position
    global_rotation = spawn_rotation

    # Rotate only the sprite by 45 degrees
    animated_sprite.rotation = deg_to_rad(90)

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
    velocity = Vector2(speed, 0).rotated(dir)
    animated_sprite.play("spin")
    move_and_slide()

func _on_lifetime_timeout():
    queue_free()