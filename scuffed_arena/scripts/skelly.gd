#@tool
extends player_class

# who is skelly???

# ranged mage, root skill shot, small crystal projectiles.
# pretty squishy

# what animations do we need?:
# idle, walk, attack, heavy attack, dash, block, hit, death

@onready var main = get_tree().get_root().get_node("Main")
@onready var attack = load("res://scenes/gem.tscn")
@onready var WalkingAudio = $AudioStreamPlayer_Walking

@export var shoot_cooldown : float = 0.5  # Time before gem respawns

var wand_gem : AnimatedSprite2D  # The visual gem on the wand
var can_shoot : bool = true

func _init():
	speed = 400
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

func _ready():
	# Create the visual gem that sits on the wand
	# Load a gem instance to get its sprite frames
	var temp_gem = attack.instantiate()
	var gem_sprite = temp_gem.get_node("AnimatedSprite2D")

	wand_gem = AnimatedSprite2D.new()
	wand_gem.sprite_frames = gem_sprite.sprite_frames
	wand_gem.scale = Vector2(0.25, 0.25)
	wand_gem.position = Vector2(-48, -64)  # Same offset as spawn position
	add_child(wand_gem)
	wand_gem.play("spin")  # Start playing the spin animation

	temp_gem.queue_free()  # Clean up the temporary gem
	#animation_tree.active = true

	# Only run multiplayer authority checks when in multiplayer mode
	if multiplayer.has_multiplayer_peer():
		var my_id = str(name).to_int()
		print("Setting authority - Node name: ", name, " -> ID: ", my_id, " | My multiplayer ID: ", multiplayer.get_unique_id())
		$MultiplayerSynchronizer.set_multiplayer_authority(my_id)
		if my_id != multiplayer.get_unique_id():
			print("Removing camera - not my character")
			remove_child($Camera2D)
		else:
			print("This is MY character - keeping camera and control")
	
func shoot():
	if not can_shoot:
		return

	var mouse_position = get_global_mouse_position()

	# Offset to spawn from top-left of character (adjust offset values as needed)
	var spawn_offset = Vector2(-64, -64)
	var rotated_offset = spawn_offset.rotated(rotation)
	var actual_spawn_position = global_position + rotated_offset

	# Calculate direction from the actual spawn position to mouse
	var direction_to_mouse = actual_spawn_position.direction_to(mouse_position)
	var angle_to_mouse = direction_to_mouse.angle()

	# Get the actual global rotation of the wand gem before we shoot it
	var wand_angle = wand_gem.global_rotation

	# Spawn on all clients via RPC
	spawn_projectile.rpc(angle_to_mouse, actual_spawn_position, wand_angle, str(name).to_int())

	# Hide the wand gem and start cooldown
	wand_gem.visible = false
	can_shoot = false

	# Create timer to respawn the gem
	var timer = Timer.new()
	timer.wait_time = shoot_cooldown
	timer.one_shot = true
	timer.timeout.connect(_on_gem_respawn)
	add_child(timer)
	timer.start()

@rpc("any_peer", "call_local")
func spawn_projectile(dir: float, spawn_pos: Vector2, spawn_rot: float, shooter: int):
	var instance = attack.instantiate()
	instance.dir = dir
	instance.spawn_position = spawn_pos
	instance.spawn_rotation = spawn_rot
	instance.shooter_id = shooter
	main.add_child.call_deferred(instance)

func _on_gem_respawn():
	wand_gem.visible = true
	can_shoot = true

	# Animate the gem zooming in from nothing
	wand_gem.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(wand_gem, "scale", Vector2(0.25, 0.25), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta):
	# Only check authority in multiplayer mode
	if multiplayer.has_multiplayer_peer():
		if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
			# This is not our character, don't process input
			return

	if not Engine.is_editor_hint():
		# Keep the wand gem animation playing
		if wand_gem and wand_gem.visible and not wand_gem.is_playing():
			wand_gem.play("spin")

		var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized();
		if dir:
			direction = dir
			velocity = direction * speed
			if !WalkingAudio.playing:
				WalkingAudio.play()
		else:
			velocity = Vector2.ZERO
			WalkingAudio.stop()

		if velocity.length() > 0:
			velocity = velocity.normalized() * speed

		var atk = Input.is_action_just_pressed("attack")

		if atk:
			shoot()

		move_and_slide()
		update_animation_parameters()
