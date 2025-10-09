extends player_class

# who is skelly???

# ranged mage, root skill shot, small crystal projectiles.
# pretty squishy

# what animations do we need?:
# idle, walk, attack, heavy attack, dash, block, hit, death

func _init():
	speed = 250
	# Create a new ability instance
	var my_ability = Ability.new()
	my_ability.id = "bone_throw"
	my_ability.display_name = "Bone Throw"
	my_ability.description = "Throws a bone at the target"
	my_ability.cooldown = 3.0
	my_ability.ability_range = 10.0
	my_ability.damage = 15.0
