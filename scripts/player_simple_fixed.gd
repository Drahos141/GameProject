extends CharacterBody3D

@export var speed: float = 15.0
var is_moving = false
var last_direction = Vector3.ZERO

func _ready() -> void:
	print("Player initialized at position: ", position)
	print("Controls: WASD or Arrow Keys to move, Click 'Map' button for minimap")
	
	# Connect UI buttons with debug output
	var minimap_btn = get_tree().root.get_node_or_null("Main/UI/MinimapButton")
	var close_btn = get_tree().root.get_node_or_null("Main/UI/MinimapPanel/CloseButton")
	
	if minimap_btn:
		minimap_btn.pressed.connect(_on_minimap_pressed)
		print("✓ Minimap button connected")
	else:
		print("✗ Minimap button NOT found")
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		print("✓ Close button connected")
	else:
		print("✗ Close button NOT found")
	
	# Load map image
	_load_map_image()


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


func _load_map_image() -> void:
	var map_path = "res://assets/map.png"
	var image_rect = get_tree().root.get_node_or_null("Main/UI/MinimapPanel/MinimapImage")
	
	if image_rect:
		if ResourceLoader.exists(map_path):
			var map_texture = load(map_path)
			image_rect.texture = map_texture
			print("Map loaded from: ", map_path)
		else:
			# Create placeholder if file doesn't exist
			print("Map file not found at: ", map_path)
			print("Place a PNG file at res://assets/map.png to display on minimap")
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
		print("Map opened")


func _on_close_pressed() -> void:
	var panel = get_tree().root.get_node_or_null("Main/UI/MinimapPanel")
	if panel:
		panel.visible = false
		print("Map closed")
