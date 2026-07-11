extends CharacterBody3D

@export var speed: float = 15.0
@export var walk_fps: float = 10.0
@export var idle_fps: float = 3.0
@export var target_sprite_world_height: float = 2.0
@export var allow_animation_hot_reload: bool = true

var is_moving = false
var last_direction = Vector3.ZERO
var facing_direction: String = "down"

const DIRECTION_KEYS := ["down", "up", "left", "right"]
const ANIMATION_RELOAD_KEY := KEY_F6

var player_sprite: AnimatedSprite3D

func _ready() -> void:
	player_sprite = get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D

	# Connect UI buttons.
	var minimap_btn = get_tree().root.get_node_or_null("Main/UI/MinimapButton")
	var close_btn = get_tree().root.get_node_or_null("Main/UI/MinimapPanel/CloseButton")
	
	if minimap_btn:
		minimap_btn.pressed.connect(_on_minimap_pressed)
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	
	# Load map image
	_load_map_image()
	_build_player_animations()
	_update_animation(Vector3.ZERO)


func _physics_process(_delta: float) -> void:
	var input_vector := Vector3.ZERO

	# Arrow keys via input map
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# WASD fallback in case input actions were modified.
	if Input.is_key_pressed(KEY_W):
		input_vector.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	
	# Normalize input
	if input_vector.length_squared() > 0.0:
		input_vector = input_vector.normalized()
		is_moving = true
		last_direction = input_vector
		facing_direction = _direction_from_input(input_vector)
	else:
		is_moving = false
	
	# Apply movement
	velocity.x = input_vector.x * speed
	velocity.z = input_vector.z * speed
	velocity.y = 0

	var previous_position := global_position
	move_and_slide()

	if input_vector.length_squared() > 0.0 and global_position.distance_to(previous_position) < 0.0001:
		# Fallback prevents edge cases where the body starts stuck in collision.
		global_position += input_vector * speed * _delta

	_update_animation(input_vector)


func _unhandled_input(event: InputEvent) -> void:
	if not allow_animation_hot_reload:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == ANIMATION_RELOAD_KEY:
		_build_player_animations()
		_update_animation(Vector3.ZERO)


func _update_animation(input_vector: Vector3) -> void:
	if not player_sprite:
		return
	if not player_sprite.sprite_frames:
		return

	var animation_name := "idle_" + facing_direction
	if input_vector.length_squared() > 0.0:
		animation_name = "walk_" + facing_direction

	if not player_sprite.sprite_frames.has_animation(animation_name):
		animation_name = "idle_down"

	if player_sprite.animation != animation_name or not player_sprite.is_playing():
		player_sprite.play(animation_name)


func _direction_from_input(input_vector: Vector3) -> String:
	if absf(input_vector.x) > absf(input_vector.z):
		if input_vector.x > 0.0:
			return "right"
		return "left"

	if input_vector.z > 0.0:
		return "down"
	return "up"


func _build_player_animations() -> void:
	if not player_sprite:
		return

	var frames := SpriteFrames.new()

	for direction in DIRECTION_KEYS:
		var texture := _load_first_existing_texture(_get_direction_texture_candidates(direction))
		if not texture:
			continue

		_add_single_frame_animation(frames, "idle_" + direction, texture, idle_fps)
		_add_single_frame_animation(frames, "walk_" + direction, texture, walk_fps)

	# Fallbacks keep animation robust even if some directions are missing.
	for direction in DIRECTION_KEYS:
		_copy_fallback_animation(frames, "idle_" + direction, "idle_down")
		_copy_fallback_animation(frames, "walk_" + direction, "idle_" + direction)

	player_sprite.sprite_frames = frames

	if frames.has_animation("idle_down") and frames.get_frame_count("idle_down") > 0:
		_fit_sprite_to_world_height(frames.get_frame_texture("idle_down", 0))


func _add_single_frame_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, fps: float) -> void:
	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, fps)
	frames.add_frame(animation_name, texture)


func _copy_fallback_animation(frames: SpriteFrames, animation_name: String, fallback_animation: String) -> void:
	if not frames.has_animation(animation_name) or not frames.has_animation(fallback_animation):
		return
	if frames.get_frame_count(animation_name) > 0:
		return

	for frame_index in range(frames.get_frame_count(fallback_animation)):
		var texture := frames.get_frame_texture(fallback_animation, frame_index)
		if texture:
			frames.add_frame(animation_name, texture)


func _get_direction_texture_candidates(direction: String) -> PackedStringArray:
	match direction:
		"down":
			return PackedStringArray([
				"res://assets/player/elf_down.png",
				"res://assets/player/idle_down.png",
				"res://assets/player/idle_down.svg"
			])
		"up":
			return PackedStringArray([
				"res://assets/player/elf_up.png",
				"res://assets/player/idle_up.png",
				"res://assets/player/idle_up.svg"
			])
		"left":
			return PackedStringArray([
				"res://assets/player/elf_left.png",
				"res://assets/player/idle_left.png",
				"res://assets/player/idle_left.svg"
			])
		"right":
			return PackedStringArray([
				"res://assets/player/elf_right.png",
				"res://assets/player/idle_right.png",
				"res://assets/player/idle_right.svg"
			])
		_:
			return PackedStringArray([])


func _load_first_existing_texture(paths: PackedStringArray) -> Texture2D:
	for path in paths:
		if not ResourceLoader.exists(path):
			continue

		var loaded_resource := load(path)
		if loaded_resource is Texture2D:
			return loaded_resource

	return null


func _fit_sprite_to_world_height(texture: Texture2D) -> void:
	if not texture or not player_sprite:
		return

	var texture_height := maxf(1.0, float(texture.get_height()))
	var sprite_scale_y := maxf(0.001, absf(player_sprite.scale.y))
	player_sprite.pixel_size = target_sprite_world_height / (texture_height * sprite_scale_y)


func _load_map_image() -> void:
	var map_path = "res://assets/map.png"
	var image_rect = get_tree().root.get_node_or_null("Main/UI/MinimapPanel/MinimapImage")
	
	if image_rect:
		if ResourceLoader.exists(map_path):
			var map_texture = load(map_path)
			image_rect.texture = map_texture
		else:
			# Create placeholder if file doesn't exist
			# Create a simple white texture as placeholder
			var placeholder = Image.new()
			placeholder.create(200, 200, false, Image.FORMAT_RGB8)
			placeholder.fill(Color.WHITE)
			var texture = ImageTexture.create_from_image(placeholder)
			image_rect.texture = texture


func _on_minimap_pressed() -> void:
	var panel = get_tree().root.get_node_or_null("Main/UI/MinimapPanel")
	if panel:
		panel.visible = true


func _on_close_pressed() -> void:
	var panel = get_tree().root.get_node_or_null("Main/UI/MinimapPanel")
	if panel:
		panel.visible = false
