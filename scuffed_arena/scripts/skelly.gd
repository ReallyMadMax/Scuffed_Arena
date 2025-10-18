@tool
extends player_class

# who is skelly???

# ranged mage, root skill shot, small crystal projectiles.
# pretty squishy

# what animations do we need?:
# idle, walk, attack, heavy attack, dash, block, hit, death

@onready var main = get_tree().get_root().get_node("Main")
@onready var attack = load("res://scenes/gem.tscn")

func _init():
	speed = 250
	# Create a new ability instance
	"""
	var my_ability = Ability.new()
	my_ability.id = "bone_throw"
	my_ability.display_name = "Bone Throw"
	my_ability.description = "Throws a bone at the target"
	my_ability.cooldown = 3.0
	my_ability.ability_range = 10.0
	my_ability.damage = 15.0
	"""

func shoot():
	var instance = attack.instantiate()
	var mouse_position = get_global_mouse_position()

	# Offset to spawn from top-left of character (adjust offset values as needed)
	var spawn_offset = Vector2(-64, -64)
	var rotated_offset = spawn_offset.rotated(rotation)
	var actual_spawn_position = global_position + rotated_offset

	# Calculate direction from the actual spawn position to mouse
	var direction_to_mouse = actual_spawn_position.direction_to(mouse_position)
	var angle_to_mouse = direction_to_mouse.angle()

	instance.dir = angle_to_mouse
	instance.spawn_position = actual_spawn_position
	instance.spawn_rotation = angle_to_mouse
	main.add_child.call_deferred(instance)


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

		var atk = Input.is_action_just_pressed("attack")

		if atk:
			shoot()

		move_and_slide()
		update_animation_parameters()
