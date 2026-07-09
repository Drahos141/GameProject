extends CharacterBody3D

@export var speed: float = 5.0

@onready var sprite_3d: Sprite3D = $Sprite3D

var facing_direction: String = "down"
var current_animation: String = "idle_down"

# Animation mapping for 3D (using sprite sheets or individual textures)
var animation_textures = {
	"idle_down": preload("res://assets/player/idle_down.svg"),
	"idle_up": preload("res://assets/player/idle_up.svg"),
	"idle_left": preload("res://assets/player/idle_left.svg"),
	"idle_right": preload("res://assets/player/idle_right.svg"),
	"walk_down": preload("res://assets/player/walk_down.svg"),
	"walk_up": preload("res://assets/player/walk_up.svg"),
	"walk_left": preload("res://assets/player/walk_left.svg"),
	"walk_right": preload("res://assets/player/walk_right.svg"),
}

func _physics_process(_delta: float) -> void:
	# Get movement input
	var move_input := Vector3(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		0.0,
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	# Support WASD keys
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.z += 1.0

	# Normalize and apply speed
	move_input = move_input.normalized()
	velocity.x = move_input.x * speed
	velocity.z = move_input.z * speed

	move_and_slide()
	_update_animation(move_input)


func _update_animation(move_input: Vector3) -> void:
	var has_movement := move_input.length_squared() > 0.0
	
	if has_movement:
		facing_direction = _direction_from_vector(move_input)

	var animation_name := "idle_" + facing_direction
	if has_movement:
		animation_name = "walk_" + facing_direction

	# Update sprite texture if animation changed
	if animation_name != current_animation:
		current_animation = animation_name
		if animation_name in animation_textures:
			sprite_3d.texture = animation_textures[animation_name]


func _direction_from_vector(move_input: Vector3) -> String:
	if absf(move_input.x) > absf(move_input.z):
		if move_input.x > 0.0:
			return "right"
		return "left"

	if move_input.z > 0.0:
		return "down"
	return "up"
