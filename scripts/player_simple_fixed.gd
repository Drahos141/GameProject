extends CharacterBody3D

@export var speed: float = 15.0
@export var walk_fps: float = 10.0
@export var idle_fps: float = 3.0
@export var target_sprite_world_height: float = 2.0
@export var allow_animation_hot_reload: bool = true

var is_moving = false
var last_direction = Vector3.ZERO
var facing_direction: String = "down"

const PLAYER_ASSET_DIR := "res://assets/player"
const DIRECTION_KEYS := ["down", "up", "left", "right"]
const SUPPORTED_IMAGE_EXTENSIONS := ["png", "webp", "svg"]
const ANIMATION_RELOAD_KEY := KEY_F6

@onready var player_sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
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
	
	# Normalize input
	if input_vector.length() > 0:
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
	
	move_and_slide()
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
		_add_animation(frames, "idle_" + direction, _collect_direction_frames("idle_" + direction), idle_fps)
		_add_animation(frames, "walk_" + direction, _collect_direction_frames("walk_" + direction), walk_fps)

	# Fallbacks keep animation robust even if some directions are missing.
	for direction in DIRECTION_KEYS:
		_ensure_animation_has_frames(frames, "idle_" + direction, "idle_down")
		if frames.get_frame_count("walk_" + direction) == 0:
			_ensure_animation_has_frames(frames, "walk_" + direction, "idle_" + direction)

	player_sprite.sprite_frames = frames

	if frames.has_animation("idle_down") and frames.get_frame_count("idle_down") > 0:
		_fit_sprite_to_world_height(frames.get_frame_texture("idle_down", 0))


func _add_animation(frames: SpriteFrames, animation_name: String, textures: Array, fps: float) -> void:
	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, fps)

	for texture in textures:
		if texture is Texture2D:
			frames.add_frame(animation_name, texture)


func _ensure_animation_has_frames(frames: SpriteFrames, animation_name: String, fallback_animation: String) -> void:
	if not frames.has_animation(animation_name) or not frames.has_animation(fallback_animation):
		return
	if frames.get_frame_count(animation_name) > 0:
		return

	for frame_index in range(frames.get_frame_count(fallback_animation)):
		var texture := frames.get_frame_texture(fallback_animation, frame_index)
		if texture:
			frames.add_frame(animation_name, texture)


func _collect_direction_frames(animation_prefix: String) -> Array:
	var frame_candidates: Array = []
	var file_names := DirAccess.get_files_at(PLAYER_ASSET_DIR)

	for file_name in file_names:
		var extension := file_name.get_extension().to_lower()
		if not SUPPORTED_IMAGE_EXTENSIONS.has(extension):
			continue

		var base_name := file_name.get_basename()
		var frame_index := _parse_frame_index(base_name, animation_prefix)
		if frame_index < 0:
			continue

		frame_candidates.append({
			"index": frame_index,
			"path": PLAYER_ASSET_DIR + "/" + file_name
		})

	frame_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["index"]) < int(b["index"])
	)

	var textures: Array = []
	for candidate in frame_candidates:
		var loaded_resource := load(String(candidate["path"]))
		if loaded_resource is Texture2D:
			textures.append(loaded_resource)

	return textures


func _parse_frame_index(base_name: String, animation_prefix: String) -> int:
	if base_name == animation_prefix:
		return 0

	var underbar_prefix := animation_prefix + "_"
	if base_name.begins_with(underbar_prefix):
		var underbar_suffix := base_name.substr(underbar_prefix.length())
		if underbar_suffix.is_valid_int():
			return int(underbar_suffix)
		return -1

	if base_name.begins_with(animation_prefix):
		var suffix := base_name.substr(animation_prefix.length())
		if suffix.is_valid_int():
			return int(suffix)

	return -1


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
