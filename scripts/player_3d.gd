extends CharacterBody3D

@export var speed: float = 5.0

@onready var sprite_3d: Sprite3D = $Sprite3D

var facing_direction: String = "down"
var current_animation: String = "idle_down"
var map_visible: bool = false
var map_ui: CanvasLayer

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

# Grass textures for random generation
var grass_textures = [
	preload("res://assets/objects/grass1.png"),
	preload("res://assets/objects/grass2.png"),
]

func _ready() -> void:
	# Get reference to map UI
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		map_ui = main_node.get_node_or_null("MapUI")
	
	print("Player ready - position: ", position)
	_generate_random_grass()
	_load_map()
	print("Game initialized successfully")


func _generate_random_grass() -> void:
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node:
		print("Main node not found")
		return
	
	var grass_container = main_node.get_node_or_null("GrassContainer")
	if not grass_container:
		print("GrassContainer not found")
		return
	
	var world_size = 100
	var grass_count = 50
	var min_distance_from_center = 3.0
	
	for i in range(grass_count):
		var x = randf_range(-world_size / 2, world_size / 2)
		var z = randf_range(-world_size / 2, world_size / 2)
		
		# Avoid spawning too close to center (player start position)
		if sqrt(x * x + z * z) < min_distance_from_center:
			continue
		
		var grass = Sprite3D.new()
		grass.position = Vector3(x, 0.5, z)
		grass.scale = Vector3(randf_range(1.5, 2.2), randf_range(1.2, 1.5), 1)
		grass.texture = grass_textures[randi() % grass_textures.size()]
		grass.billboard = 2  # BILLBOARD_FIXED_Y
		grass_container.add_child(grass)


func _load_map() -> void:
	if not map_ui:
		return
	
	# Try to load map texture - create a simple placeholder if it doesn't exist
	var map_path = "res://assets/map.png"
	if ResourceLoader.exists(map_path):
		var map_texture = load(map_path)
		var map_rect = map_ui.get_node_or_null("MapPanel/MapTexture")
		if map_rect:
			map_rect.texture = map_texture
	else:
		print("Map file not found at: ", map_path)


func _physics_process(_delta: float) -> void:
	# Check for map toggle (M key)
	if Input.is_key_just_pressed(KEY_M):
		_toggle_map()
	
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


func _toggle_map() -> void:
	if map_ui:
		map_visible = !map_visible
		map_ui.visible = map_visible


func _direction_from_vector(move_input: Vector3) -> String:
	if absf(move_input.x) > absf(move_input.z):
		if move_input.x > 0.0:
			return "right"
		return "left"

	if move_input.z > 0.0:
		return "down"
	return "up"
