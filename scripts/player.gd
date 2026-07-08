extends CharacterBody2D

@export var speed: float = 220.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fallback_body: Node2D = $Body

var facing_direction: String = "down"

func _physics_process(_delta: float) -> void:
	# Supports both built-in UI actions (arrow keys) and direct WASD keys.
	var move_input := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.y += 1.0

	velocity = move_input.normalized() * speed
	move_and_slide()
	_update_animation(move_input)


func _update_animation(move_input: Vector2) -> void:
	var has_movement := move_input.length_squared() > 0.0
	if has_movement:
		facing_direction = _direction_from_vector(move_input)

	var animation_name := "idle_" + facing_direction
	if has_movement:
		animation_name = "walk_" + facing_direction

	if _play_if_has_frames(animation_name):
		if fallback_body:
			fallback_body.visible = false
		return

	if fallback_body:
		fallback_body.visible = true
	if animated_sprite:
		animated_sprite.stop()


func _play_if_has_frames(animation_name: String) -> bool:
	if not animated_sprite:
		return false

	var frames := animated_sprite.sprite_frames
	if not frames:
		return false
	if not frames.has_animation(animation_name):
		return false
	if frames.get_frame_count(animation_name) <= 0:
		return false

	animated_sprite.play(animation_name)
	return true


func _direction_from_vector(move_input: Vector2) -> String:
	if absf(move_input.x) > absf(move_input.y):
		if move_input.x > 0.0:
			return "right"
		return "left"

	if move_input.y > 0.0:
		return "down"
	return "up"
