@abstract
extends CharacterBody2D
class_name Player

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
@onready var ability = preload("res://scripts/ability.gd")
# Load the hit particles scene
@onready var HitParticles = preload("res://scenes/hit_particles.tscn")

var direction : Vector2
var is_dead : bool = false
var death_count : int = 0  # Track number of deaths
var healthbar_bg : ColorRect  # Background bar
var healthbar_fg : ColorRect  # Foreground health bar
var death_counter_label : Label  # Death counter display

var upgrades:Array = []

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
func take_damage(amount: int, source: Player):
	print("take_damage called with amount: ", amount, " | is_dead: ", is_dead, " | current_health: ", current_health)
	if is_dead:
		print("Player is already dead, ignoring damage")
		return

	current_health -= amount
	print("Player ", name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	update_healthbar()

	# Spawn hit particles based on damage amount
	spawn_hit_particles(amount)

	for upgrade in upgrades:
		upgrade.on_damage_taken(self, amount, source)
	if current_health <= 0:
		print("Health reached 0, calling die()")
		die(source)

func spawn_hit_particles(damage: int):
	# Instantiate the particle system
	var particles = HitParticles.instantiate()

	# Add to parent (the game world) so particles persist even if player moves/dies
	get_parent().add_child(particles)

	# Position at player's current position
	particles.global_position = global_position

	# Scale particle count based on damage (minimum 10, scales up with damage)
	# Formula: base 10 particles + 1 particle per 10 damage
	var particle_count = int(clamp(10 + (damage / 10.0), 10, 100))
	particles.amount = particle_count

	# Scale particle velocity based on damage for more impact on bigger hits
	var velocity_multiplier = clamp(1.0 + (damage / 200.0), 1.0, 2.5)
	particles.initial_velocity_min = 100.0 * velocity_multiplier
	particles.initial_velocity_max = 200.0 * velocity_multiplier

	# Emit the particles
	particles.emitting = true

	# Auto-cleanup after particles finish (lifetime + some buffer)
	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	particles.queue_free()

@rpc("any_peer", "call_local")
func die(source: Player):
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
	source.on_kill(self)

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

# happens on every instance of damage dealth
func on_damage_dealt(damage: float) -> void:
	for upgrade in upgrades:
		upgrade.on_damage_dealt(self, damage)

func on_kill(enemy: Player) -> void:
	for upgrade in upgrades:
		upgrade.on_kill(self, enemy)

# happens the first time you hit someone
func on_hit(enemy: Player) -> void:
	for upgrade in upgrades:
		upgrade.on_hit(self, enemy)

func add_upgrade(upgrade:Upgrade) -> void:
	upgrades.append(upgrade)
	upgrade.apply(self)

func remove_upgrade(upgrade:Upgrade) -> Upgrade:
	# TODO: make this remove the one we actually want
	upgrades.remove_at(0)
	upgrade.remove(self)
	return upgrade
