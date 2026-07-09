extends CharacterBody3D

@export var speed: float = 15.0
var is_moving = false
var last_direction = Vector3.ZERO

func _ready() -> void:
	print("Player initialized at position: ", position)
	print("Controls: WASD or Arrow Keys to move, M for map")

func _physics_process(delta: float) -> void:
	var input_vector = Vector3.ZERO
	
	# Collect all input
	if Input.is_key_pressed(KEY_W):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	
	# Arrow keys
	if Input.is_key_pressed(KEY_UP):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0
	
	# Map toggle
	if Input.is_key_just_pressed(KEY_M):
		print("Map toggled (feature available for expansion)")
	
	# Normalize input
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		is_moving = true
		last_direction = input_vector
	else:
		is_moving = false
	
	# Apply movement
	velocity.x = input_vector.x * speed
	velocity.z = input_vector.z * speed
	velocity.y = 0
	
	move_and_slide()
	
	if is_moving:
		print("Position: ", position)
