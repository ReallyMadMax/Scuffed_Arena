#@tool
extends player_class

func _init():
	speed = 350

func _ready():
	super._ready()  # Call parent _ready to initialize current_health
	animation_tree.active = true
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	if str(name).to_int() != multiplayer.get_unique_id():
		remove_child($Camera2D)

func _process(_delta):
	if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
		return

	# Don't process input if player is dead
	if is_dead:
		return

	if not Engine.is_editor_hint():
		# Test keybind: Press 'g' to damage yourself
		if Input.is_action_just_pressed("test"):
			print("Test key pressed! Dealing damage...")
			take_damage(250)  # Deal 250 damage to self

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
