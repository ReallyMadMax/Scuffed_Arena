#@tool
extends Player

# who is skelly???

# ranged mage, root skill shot, small crystal projectiles.
# pretty squishy

# what animations do we need?:
# idle, walk, attack, heavy attack, dash, block, hit, death

@onready var main = get_tree().get_root().get_node("Main")
@onready var WalkingAudio = $AudioStreamPlayer_Walking

@export var shoot_cooldown : float = 0.5  # Time before gem respawns

var gem_point : Node2D  # Gem attachment point
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
	super._ready()  # Call parent _ready to initialize current_health
	#animation_tree.active = true

# Override parent die() to reset wand gem state
func die(source:int):
	super.die(source)
	# Reset shooting state on death
	can_shoot = false
	if wand_gem:
		wand_gem.visible = false

# Override parent respawn() to restore wand gem
func respawn():
	super.respawn()
	# Restore shooting ability on respawn
	can_shoot = true
	if wand_gem:
		wand_gem.visible = true
		wand_gem.scale = Vector2(0.25, 0.25)


func _process(_delta):
	# Only check authority in multiplayer mode
	if multiplayer.has_multiplayer_peer():
		if $MultiplayerSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
			# This is not our character, don't process input
			return

	# Don't process input if player is dead
	if is_dead:
		return

	if not Engine.is_editor_hint():
		# Test keybind: Press 'g' to damage yourself
		if Input.is_action_just_pressed("test"):
			print("Test key pressed! Dealing damage...")
			take_damage(250, 0)  # Deal 250 damage to self #TODO: give players their ID

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

		if Input.is_action_just_pressed("attack"):
			print("attack")

		move_and_slide()
		update_animation_parameters()
