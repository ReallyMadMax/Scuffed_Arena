extends CharacterBody2D

@export var speed = 300
var direction : Vector2

@onready var animation_tree : AnimationTree = $AnimationTree

func _ready():
	animation_tree.active = true
	print("Hello, world!")
	print(5*23)

func _process(delta):
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized();
	if dir:
		direction = dir
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed

	move_and_slide()
	update_animation_parameters()

func update_animation_parameters():
	if (velocity == Vector2.ZERO):
		animation_tree["parameters/conditions/is_idle"] = true
		animation_tree["parameters/conditions/is_moving"] = false
	else:
		animation_tree["parameters/conditions/is_idle"] = false
		animation_tree["parameters/conditions/is_moving"] = true
	
	if Input.is_action_just_pressed("attack"):
		animation_tree["parameters/conditions/attack"] = true
	else:
		animation_tree["parameters/conditions/attack"] = false
	
	animation_tree["parameters/Idle/blend_position"] = direction
	animation_tree["parameters/Move/blend_position"] = direction
	animation_tree["parameters/Attack/blend_position"] = direction
