#@tool
extends player_class

func _init():
	speed = 350

func _ready():
	super._ready()  # Call parent to duplicate inventory
	animation_tree.active = true

	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	if str(name).to_int() != multiplayer.get_unique_id():
		remove_child($Camera2D)
	
	
func _process(_delta):
	
	if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	
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

func player():
	pass

