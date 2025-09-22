extends Area2D

@export var speed = 350

func _ready():
	print(speed)

func _process(delta):
	var velocity = Vector2.ZERO # The player's movement vector.
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
		print(speed)
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
		print(speed)
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
		print(speed)
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1
		print(speed)
	if Input.is_action_pressed("sprint"):
		speed = 700
		print(speed)
	else:
		speed = 350
		print(speed)

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()

	if velocity.x == 0 && velocity.y == 0:
		$AnimatedSprite2D.play("idle")

	if velocity.y > 0:
		$AnimatedSprite2D.play("down")
		$AnimatedSprite2D.flip_h = true
	elif velocity.y < 0:
		$AnimatedSprite2D.play("up")
	
	if velocity.x > 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = true
	elif velocity.x < 0:
		$AnimatedSprite2D.play("walk")
		$AnimatedSprite2D.flip_h = false

	position += velocity * delta
