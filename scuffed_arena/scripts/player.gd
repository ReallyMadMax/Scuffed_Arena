@tool
extends player_class

@export var inv: Inv
func _init():
	speed = 250

func _ready():
	animation_tree.active = true

func _process(delta):
	if not Engine.is_editor_hint():
		var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized();
		if dir:
			direction = dir
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO 

		if velocity.length() > 0:
			velocity = velocity.normalized() * speed

		position += velocity * delta
		update_animation_parameters()

func collect(item):
	inv.insert(item)
