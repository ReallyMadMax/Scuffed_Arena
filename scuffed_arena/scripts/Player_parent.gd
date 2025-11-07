@abstract
class_name player_class
extends CharacterBody2D

signal player_died(player_id: int)

@export var speed = 300
@export var max_health = 1000
@export var current_health = max_health
@export var basic_attack_cd = 1
@export var heavy_attack_cd = 5
@export var block_cd = 10
@export var dash_cd = 5

@onready var animation_tree : AnimationTree = $AnimationTree
# Load the Ability script as a resource so that it can be used in sub player characters
@onready var Ability = preload("res://scripts/ability.gd")

var direction : Vector2
var is_dead : bool = false
var death_count : int = 0  # Track number of deaths
var healthbar_bg : ColorRect  # Background bar
var healthbar_fg : ColorRect  # Foreground health bar
var death_counter_label : Label  # Death counter display

@abstract
# initialize basic vars here
func _init()

func _ready():
	# Initialize current_health after export vars are set
	current_health = max_health

	# Create healthbar using ColorRect for precise control
	# Background bar (dark gray)
	healthbar_bg = ColorRect.new()
	healthbar_bg.size = Vector2(64, 4)
	healthbar_bg.position = Vector2(-32, 82)  # Moved down 10 pixels
	healthbar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	add_child(healthbar_bg)

	# Foreground bar (health - starts green)
	healthbar_fg = ColorRect.new()
	healthbar_fg.size = Vector2(64, 4)
	healthbar_fg.position = Vector2(-32, 82)  # Moved down 10 pixels
	healthbar_fg.color = Color(0.0, 1.0, 0.0, 1.0)
	add_child(healthbar_fg)

	# Create death counter label (to the right of health bar)
	death_counter_label = Label.new()
	death_counter_label.position = Vector2(36, 70)  # Right of health bar, aligned vertically
	death_counter_label.add_theme_font_size_override("font_size", 20)
	death_counter_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))  # Light red
	death_counter_label.visible = false  # Hidden initially
	add_child(death_counter_label)

func update_healthbar():
	if healthbar_fg:
		# Calculate health percentage and update bar width
		var health_percent = float(current_health) / float(max_health)
		healthbar_fg.size.x = 64 * health_percent

		# Change color based on health percentage
		if health_percent > 0.6:
			healthbar_fg.color = Color(0.0, 1.0, 0.0, 1.0)  # Green
		elif health_percent > 0.3:
			healthbar_fg.color = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
		else:
			healthbar_fg.color = Color(1.0, 0.0, 0.0, 1.0)  # Red

func update_death_counter():
	if death_counter_label:
		if death_count > 0:
			death_counter_label.text = str(death_count)
			death_counter_label.visible = true
		else:
			death_counter_label.visible = false 

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

@rpc("any_peer", "call_local")
func take_damage(amount: int):
	print("take_damage called with amount: ", amount, " | is_dead: ", is_dead, " | current_health: ", current_health)
	if is_dead:
		print("Player is already dead, ignoring damage")
		return

	current_health -= amount
	print("Player ", name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	update_healthbar()
	if current_health <= 0:
		print("Health reached 0, calling die()")
		die()

@rpc("any_peer", "call_local")
func die():
	if is_dead:
		return

	is_dead = true
	current_health = 0
	velocity = Vector2.ZERO

	# Increment death counter
	death_count += 1
	update_death_counter()

	# Hide the player visually
	visible = false
	if healthbar_bg:
		healthbar_bg.visible = false
	if healthbar_fg:
		healthbar_fg.visible = false
	if death_counter_label:
		death_counter_label.visible = false

	print("Player ", name, " died! Emitting death signal...")

	# Emit signal to main scene to handle respawn timing
	var player_id = int(name)
	player_died.emit(player_id)

@rpc("any_peer", "call_local")
func respawn():
	print("Player ", name, " respawning...")
	is_dead = false
	current_health = max_health
	visible = true

	# Show and update healthbar
	if healthbar_bg:
		healthbar_bg.visible = true
	if healthbar_fg:
		healthbar_fg.visible = true
		update_healthbar()

	# Update death counter visibility (only show if > 0)
	update_death_counter()

	print("Player ", name, " respawned at ", global_position, " with ", current_health, " health")
