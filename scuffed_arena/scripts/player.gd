@tool
extends player_class

func _init():
	speed = 350

func _ready():
	animation_tree.active = true

func _process(_delta):
	if not Engine.is_editor_hint():
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
