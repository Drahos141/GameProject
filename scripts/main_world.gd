extends Node3D

@export var grass_cluster_count: int = 28
@export var grass_per_cluster: int = 18
@export var grass_scatter_count: int = 110
@export var tree_count: int = 18
@export var rock_count: int = 30
@export var flower_count: int = 70
@export var enemy_count: int = 8
@export var enemy_base_count: int = 2
@export var enemy_per_level_increase: int = 1
@export var enemy_health: int = 1
@export var enemy_spawn_distance: float = 18.0
@export var enemy_spawn_max_distance: float = 34.0
@export var enemy_wave_size: int = 3
@export var enemy_wave_interval: float = 14.0
@export var starting_level: int = 1
@export var day_night_cycle_duration: float = 120.0
@export var grass_gather_range: float = 3.0
@export var player_attack_range: float = 2.4
@export var player_attack_damage: int = 1
@export var player_max_health: int = 10
@export var rope_grass_cost: int = 5
@export var grass_house_cost: int = 30
@export var grass_house_duration_seconds: float = 60.0
@export var grass_house_hide_radius: float = 2.2
@export var grass_margin: float = 3.0
@export var keep_clear_radius: float = 3.5
@export var generation_seed: int = 1337
@export var cluster_radius: float = 10.0

const GRASS_TEXTURES := [
	preload("res://assets/objects/grass1.png"),
	preload("res://assets/objects/grass2.png")
]
const INVALID_SPAWN_POSITION := Vector3(INF, INF, INF)

@onready var ground: StaticBody3D = $Ground
@onready var grass_container: Node3D = $GeneratedGrass
@onready var prop_container: Node3D = $GeneratedProps
@onready var enemy_container: Node3D = $GeneratedEnemies
@onready var player: CharacterBody3D = $Player
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var restart_button: Button = $UI/GameOverPanel/RestartButton
@onready var wave_timer: Timer = $EnemyWaveTimer
@onready var day_night_label: Label = $UI/DayNightLabel
@onready var level_label: Label = $UI/LevelLabel
@onready var inventory_button: Button = $UI/InventoryButton
@onready var inventory_panel: Panel = $UI/InventoryPanel
@onready var inventory_close_button: Button = $UI/InventoryPanel/CloseButton
@onready var inventory_count_label: Label = $UI/InventoryPanel/GrassCountLabel
@onready var inventory_rope_label: Label = $UI/InventoryPanel/RopeCountLabel
@onready var build_button: Button = $UI/BuildButton
@onready var build_panel: Panel = $UI/BuildPanel
@onready var build_close_button: Button = $UI/BuildPanel/CloseButton
@onready var build_craft_rope_button: Button = $UI/BuildPanel/CraftRopeButton
@onready var build_status_label: Label = $UI/BuildPanel/StatusLabel
@onready var gather_hint_label: Label = $UI/GatherHintLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var player_camera: Camera3D = $Player/Camera
@onready var world_light: DirectionalLight3D = $Light
@onready var world_environment: WorldEnvironment = $Environment

var is_game_over: bool = false
var spawn_rng := RandomNumberGenerator.new()
var current_level: int = 1
var is_daytime: bool = true
var cycle_time_remaining: float = 0.0
var day_night_transitions: int = 0
var grass_collected_count: int = 0
var rope_count: int = 0
var player_health: int = 10
var build_grass_house_button: Button
var house_placement_mode: bool = false
var active_grass_house: Node3D
var grass_house_expire_time: float = -1.0
var elapsed_time: float = 0.0
var is_player_hidden: bool = false
var _space_was_pressed: bool = false
var _e_was_pressed: bool = false


func _ready() -> void:
	spawn_rng.seed = generation_seed
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_connect_ui_signals()
	_ensure_build_house_button()
	if build_grass_house_button and not build_grass_house_button.pressed.is_connected(_on_build_grass_house_pressed):
		build_grass_house_button.pressed.connect(_on_build_grass_house_pressed)
	_reset_progression_state()
	_generate_world()
	_update_inventory_ui()


func _process(delta: float) -> void:
	elapsed_time += delta
	_handle_action_inputs()
	_update_gather_hint()
	_update_grass_house_state()
	_update_player_hide_state()

	if is_game_over or day_night_cycle_duration <= 0.0:
		return

	cycle_time_remaining -= delta
	while cycle_time_remaining <= 0.0:
		cycle_time_remaining += day_night_cycle_duration
		is_daytime = not is_daytime
		day_night_transitions += 1
		if day_night_transitions % 2 == 0:
			current_level += 1
			if current_level % 2 == 0:
				_regenerate_grass_for_level(current_level)

		if is_daytime:
			_clear_enemies()
		else:
			_spawn_enemies_for_level(current_level)

		_sync_enemy_targets()
		_apply_day_night_visuals()

	_update_ui_labels()


func _input(event: InputEvent) -> void:
	if is_game_over:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if house_placement_mode and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			house_placement_mode = false
			_update_build_ui("House placement canceled")
			return
		if house_placement_mode and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if get_viewport().gui_get_hovered_control() != null:
				return
			_try_place_grass_house_from_screen(mouse_event.position)
			return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE and house_placement_mode:
			house_placement_mode = false
			_update_build_ui("House placement canceled")


func _handle_action_inputs() -> void:
	if is_game_over:
		_space_was_pressed = Input.is_key_pressed(KEY_SPACE)
		_e_was_pressed = Input.is_key_pressed(KEY_E)
		return

	if Input.is_key_pressed(KEY_I):
		_on_inventory_button_pressed()
	if Input.is_key_pressed(KEY_B):
		_on_build_button_pressed()

	var space_pressed := Input.is_key_pressed(KEY_SPACE)
	if space_pressed and not _space_was_pressed:
		# Space prioritizes attack; if no enemy is in range, it gathers grass.
		if not _try_attack_nearest_enemy():
			_try_gather_nearest_grass()
	_space_was_pressed = space_pressed

	var e_pressed := Input.is_key_pressed(KEY_E)
	if e_pressed and not _e_was_pressed:
		_try_gather_nearest_grass()
	_e_was_pressed = e_pressed


func _generate_world() -> void:
	if not ground or not grass_container or not prop_container or not enemy_container:
		return

	_clear_container(grass_container)
	_clear_container(prop_container)
	_clear_container(enemy_container)
	is_game_over = false
	if game_over_panel:
		game_over_panel.visible = false
	if player and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(true)
	if wave_timer:
		wave_timer.stop()
	spawn_rng.seed = generation_seed

	var ground_size := _get_ground_size()
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed

	var protected_points := _get_protected_points()
	_generate_grass_clusters(rng, ground_size, protected_points)
	_generate_scattered_grass(rng, ground_size, protected_points)
	_generate_trees(rng, ground_size, protected_points)
	_generate_rocks(rng, ground_size, protected_points)
	_generate_flowers(rng, ground_size, protected_points)
	if not is_daytime:
		_spawn_enemies_for_level(current_level)


func _reset_progression_state() -> void:
	current_level = maxi(1, starting_level)
	is_daytime = true
	cycle_time_remaining = day_night_cycle_duration
	day_night_transitions = 0
	grass_collected_count = 0
	rope_count = 0
	player_health = player_max_health
	elapsed_time = 0.0
	house_placement_mode = false
	is_player_hidden = false
	_clear_active_grass_house()
	_apply_day_night_visuals()
	_update_ui_labels()
	_update_inventory_ui()
	_update_build_ui("")


func _spawn_enemies_for_level(level: int) -> void:
	if is_game_over:
		return

	var ground_size := _get_ground_size()
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return

	var protected_points := _get_protected_points()
	var level_enemy_count: int = maxi(enemy_base_count, enemy_base_count + (level - 1) * enemy_per_level_increase)
	_generate_enemies(spawn_rng, ground_size, protected_points, level_enemy_count)


func _apply_day_night_visuals() -> void:
	if world_light:
		if is_daytime:
			world_light.light_energy = 1.6
			world_light.light_color = Color(1.0, 0.97, 0.91, 1.0)
		else:
			world_light.light_energy = 0.45
			world_light.light_color = Color(0.58, 0.69, 0.94, 1.0)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		if is_daytime:
			env.background_color = Color(0.83, 0.92, 1.0, 1.0)
			env.ambient_light_color = Color(0.98, 0.99, 1.0, 1.0)
			env.ambient_light_energy = 1.2
		else:
			env.background_color = Color(0.08, 0.11, 0.19, 1.0)
			env.ambient_light_color = Color(0.35, 0.43, 0.6, 1.0)
			env.ambient_light_energy = 0.38


func _update_ui_labels() -> void:
	if level_label:
		var seconds_until_level := cycle_time_remaining
		if day_night_transitions % 2 == 0:
			seconds_until_level += day_night_cycle_duration
		var level_total_seconds := maxi(0, int(ceil(seconds_until_level)))
		var level_minutes := level_total_seconds / 60
		var level_seconds := level_total_seconds % 60
		level_label.text = "LEVEL %d | Next %02d:%02d" % [current_level, level_minutes, level_seconds]

	if day_night_label:
		var phase_text := "DAY" if is_daytime else "NIGHT"
		var total_seconds := maxi(0, int(ceil(cycle_time_remaining)))
		var minutes := total_seconds / 60
		var seconds := total_seconds % 60
		day_night_label.text = "%s %02d:%02d" % [phase_text, minutes, seconds]

	if health_label:
		health_label.text = "HP %d/%d" % [player_health, player_max_health]


func _update_inventory_ui() -> void:
	if inventory_button:
		inventory_button.text = "Inventory"

	if inventory_count_label:
		inventory_count_label.text = "Grass: %d" % grass_collected_count

	if inventory_rope_label:
		inventory_rope_label.text = "Rope: %d" % rope_count


func _update_build_ui(status_text: String) -> void:
	if build_craft_rope_button:
		build_craft_rope_button.disabled = grass_collected_count < rope_grass_cost
	if build_grass_house_button:
		build_grass_house_button.disabled = grass_collected_count < grass_house_cost or house_placement_mode

	if build_status_label:
		if status_text.is_empty():
			if house_placement_mode:
				build_status_label.text = "Click ground to place Grass House"
			else:
				build_status_label.text = "Need %d Grass for Rope | %d for House" % [rope_grass_cost, grass_house_cost]
		else:
			build_status_label.text = status_text


func _update_gather_hint() -> void:
	if not gather_hint_label:
		return
	if is_game_over:
		gather_hint_label.visible = false
		return

	gather_hint_label.visible = _find_nearest_grass_in_range(grass_gather_range) != null


func _try_gather_nearest_grass() -> bool:
	if not player or not grass_container:
		return false

	var nearest_grass := _find_nearest_grass_in_range(grass_gather_range)
	if not nearest_grass:
		nearest_grass = _find_nearest_grass_in_range(grass_gather_range * 3.0)
	if nearest_grass:
		grass_collected_count += 1
		nearest_grass.queue_free()
		_update_inventory_ui()
		_update_build_ui("")
		return true

	return false


func _try_attack_nearest_enemy() -> bool:
	var enemy := _find_nearest_enemy_in_range(player_attack_range)
	if not enemy:
		enemy = _find_nearest_enemy_in_range(player_attack_range * 2.0)
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(player_attack_damage)
		return true

	return false


func _connect_ui_signals() -> void:
	if restart_button and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)

	if wave_timer and not wave_timer.timeout.is_connected(_on_enemy_wave_timer_timeout):
		wave_timer.timeout.connect(_on_enemy_wave_timer_timeout)

	if inventory_button and not inventory_button.pressed.is_connected(_on_inventory_button_pressed):
		inventory_button.pressed.connect(_on_inventory_button_pressed)

	if inventory_close_button and not inventory_close_button.pressed.is_connected(_on_inventory_close_button_pressed):
		inventory_close_button.pressed.connect(_on_inventory_close_button_pressed)

	if build_button and not build_button.pressed.is_connected(_on_build_button_pressed):
		build_button.pressed.connect(_on_build_button_pressed)

	if build_close_button and not build_close_button.pressed.is_connected(_on_build_close_button_pressed):
		build_close_button.pressed.connect(_on_build_close_button_pressed)

	if build_craft_rope_button and not build_craft_rope_button.pressed.is_connected(_on_build_craft_rope_pressed):
		build_craft_rope_button.pressed.connect(_on_build_craft_rope_pressed)


func _ensure_build_house_button() -> void:
	if not build_panel:
		return

	build_grass_house_button = build_panel.get_node_or_null("BuildGrassHouseButton") as Button
	if build_grass_house_button:
		return

	build_grass_house_button = Button.new()
	build_grass_house_button.name = "BuildGrassHouseButton"
	build_grass_house_button.layout_mode = 0
	build_grass_house_button.offset_left = 18.0
	build_grass_house_button.offset_top = 108.0
	build_grass_house_button.offset_right = 230.0
	build_grass_house_button.offset_bottom = 146.0
	build_grass_house_button.text = "Build House (30 Grass)"
	build_panel.add_child(build_grass_house_button)

	if build_status_label:
		build_status_label.offset_top = 156.0
		build_status_label.offset_bottom = 194.0


func _on_build_grass_house_pressed() -> void:
	if grass_collected_count < grass_house_cost:
		_update_build_ui("Not enough Grass for House")
		return

	house_placement_mode = true
	_update_build_ui("")


func _try_place_grass_house_from_screen(screen_position: Vector2) -> void:
	if not player_camera or not ground:
		return

	var ray_origin := player_camera.project_ray_origin(screen_position)
	var ray_direction := player_camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_update_build_ui("Click on ground to place House")
		return

	var collider: Object = result.get("collider")
	if collider != ground:
		_update_build_ui("Place House on ground")
		return

	if grass_collected_count < grass_house_cost:
		house_placement_mode = false
		_update_build_ui("Not enough Grass for House")
		return

	grass_collected_count -= grass_house_cost
	_update_inventory_ui()

	var position := result.get("position") as Vector3
	position.y = 0.0
	_place_grass_house(position)
	house_placement_mode = false
	_update_build_ui("House built for 60 seconds")


func _place_grass_house(position: Vector3) -> void:
	_clear_active_grass_house()

	var house := Node3D.new()
	house.name = "GrassHouse"
	house.position = position

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.8, 1.8, 2.8)
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.9, 0.0)
	body.material_override = _make_colored_material(Color(0.45, 0.72, 0.28, 1.0), 0.95)
	house.add_child(body)

	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.left_to_right = 2.8
	roof_mesh.size = Vector3(3.2, 1.0, 3.2)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 2.0, 0.0)
	roof.material_override = _make_colored_material(Color(0.36, 0.58, 0.2, 1.0), 0.9)
	house.add_child(roof)

	var marker := Label3D.new()
	marker.text = "Safe House"
	marker.position = Vector3(0.0, 2.8, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	house.add_child(marker)

	add_child(house)
	active_grass_house = house
	grass_house_expire_time = elapsed_time + grass_house_duration_seconds


func _update_grass_house_state() -> void:
	if not active_grass_house:
		return

	if elapsed_time >= grass_house_expire_time:
		_clear_active_grass_house()
		house_placement_mode = false
		_update_build_ui("House expired")


func _clear_active_grass_house() -> void:
	if active_grass_house and is_instance_valid(active_grass_house):
		active_grass_house.queue_free()
	active_grass_house = null
	grass_house_expire_time = -1.0


func _update_player_hide_state() -> void:
	var hidden_now := false
	if player and active_grass_house and is_instance_valid(active_grass_house):
		hidden_now = player.global_position.distance_to(active_grass_house.global_position) <= grass_house_hide_radius

	if hidden_now == is_player_hidden:
		return

	is_player_hidden = hidden_now
	_sync_enemy_targets()


func _sync_enemy_targets() -> void:
	for node in enemy_container.get_children():
		if not (node is CharacterBody3D):
			continue

		var enemy := node as CharacterBody3D
		if is_daytime or is_player_hidden:
			enemy.set("target", null)
		else:
			enemy.set("target", player)


func _clear_enemies() -> void:
	for enemy_node in enemy_container.get_children():
		enemy_node.queue_free()


func _regenerate_grass_for_level(level: int) -> void:
	if not grass_container or not ground:
		return

	var ground_size := _get_ground_size()
	if ground_size.x <= 0.0 or ground_size.y <= 0.0:
		return

	var protected_points := _get_protected_points()
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed + level * 7919 + grass_container.get_child_count()

	var regen_count := maxi(24, grass_scatter_count / 3)
	for _index in range(regen_count):
		var position := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius)
		if position == INVALID_SPAWN_POSITION:
			continue

		grass_container.add_child(_build_grass_sprite(position, rng))


func _find_nearest_enemy_in_range(max_range: float) -> CharacterBody3D:
	var nearest_enemy: CharacterBody3D = null
	var nearest_distance := max_range

	for node in enemy_container.get_children():
		if not (node is CharacterBody3D):
			continue

		var enemy := node as CharacterBody3D
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy


func _find_nearest_grass_in_range(max_range: float) -> Sprite3D:
	var nearest_grass: Sprite3D = null
	var nearest_distance := max_range

	for node in grass_container.get_children():
		if not (node is Sprite3D):
			continue

		var grass := node as Sprite3D
		var distance := player.global_position.distance_to(grass.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_grass = grass

	return nearest_grass


func _on_inventory_button_pressed() -> void:
	if inventory_panel:
		inventory_panel.visible = true


func _on_inventory_close_button_pressed() -> void:
	if inventory_panel:
		inventory_panel.visible = false


func _on_build_button_pressed() -> void:
	if build_panel:
		build_panel.visible = true
	_update_build_ui("")


func _on_build_close_button_pressed() -> void:
	if build_panel:
		build_panel.visible = false


func _on_build_craft_rope_pressed() -> void:
	if grass_collected_count < rope_grass_cost:
		_update_build_ui("Not enough Grass")
		return

	grass_collected_count -= rope_grass_cost
	rope_count += 1
	_update_inventory_ui()
	_update_build_ui("Crafted 1 Rope")


func _clear_container(container: Node3D) -> void:
	for child in container.get_children():
		child.queue_free()


func _generate_grass_clusters(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> void:
	for _cluster_index in range(grass_cluster_count):
		var center := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius + 2.0)
		if center == INVALID_SPAWN_POSITION:
			continue

		for _item_index in range(grass_per_cluster):
			var offset: Vector3 = Vector3(
				rng.randf_range(-cluster_radius, cluster_radius),
				0.0,
				rng.randf_range(-cluster_radius, cluster_radius)
			)
			if offset.length() > cluster_radius:
				offset = offset.normalized() * rng.randf_range(cluster_radius * 0.2, cluster_radius)

			var position := _clamp_to_ground(center + offset, ground_size)
			if _is_in_protected_area(position, protected_points):
				continue

			grass_container.add_child(_build_grass_sprite(position, rng))


func _generate_scattered_grass(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> void:
	for _index in range(grass_scatter_count):
		var position := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius)
		if position == INVALID_SPAWN_POSITION:
			continue

		grass_container.add_child(_build_grass_sprite(position, rng))


func _generate_trees(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> void:
	for _index in range(tree_count):
		var position := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius + 5.0)
		if position == INVALID_SPAWN_POSITION:
			continue

		prop_container.add_child(_build_tree(position, rng))


func _generate_rocks(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> void:
	for _index in range(rock_count):
		var position := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius + 1.0)
		if position == INVALID_SPAWN_POSITION:
			continue

		prop_container.add_child(_build_rock(position, rng))


func _generate_flowers(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> void:
	for _index in range(flower_count):
		var position := _find_spawn_position(rng, ground_size, protected_points, keep_clear_radius)
		if position == INVALID_SPAWN_POSITION:
			continue

		prop_container.add_child(_build_flower(position, rng))


func _generate_enemies(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3], count: int) -> void:
	for _index in range(count):
		var position := _find_enemy_spawn_position(rng, ground_size, protected_points)
		if position == INVALID_SPAWN_POSITION:
			continue

		var enemy := _build_enemy(position, rng)
		enemy_container.add_child(enemy)
		enemy.attacked_player.connect(_on_enemy_attacked_player)
		enemy.defeated.connect(_on_enemy_defeated)


func _find_enemy_spawn_position(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3]) -> Vector3:
	var attempts := 0
	var player_position := Vector3.ZERO
	if player:
		player_position = player.position

	while attempts < 40:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(enemy_spawn_distance, enemy_spawn_max_distance)
		var candidate := player_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var position := _clamp_to_ground(candidate, ground_size)

		if player and position.distance_to(player.position) < enemy_spawn_distance:
			continue
		if _is_in_protected_area(position, protected_points, keep_clear_radius + 1.0):
			continue

		return position

	return _find_spawn_position(rng, ground_size, protected_points, enemy_spawn_distance)


func _find_spawn_position(rng: RandomNumberGenerator, ground_size: Vector2, protected_points: Array[Vector3], min_distance: float) -> Vector3:
	var attempts := 0
	var half_width := maxf(0.0, ground_size.x * 0.5 - grass_margin)
	var half_depth := maxf(0.0, ground_size.y * 0.5 - grass_margin)

	while attempts < 30:
		attempts += 1

		var position := Vector3(
			rng.randf_range(-half_width, half_width),
			0.0,
			rng.randf_range(-half_depth, half_depth)
		)

		if _is_in_protected_area(position, protected_points, min_distance):
			continue

		return position

	return INVALID_SPAWN_POSITION


func _clamp_to_ground(position: Vector3, ground_size: Vector2) -> Vector3:
	var half_width := maxf(0.0, ground_size.x * 0.5 - grass_margin)
	var half_depth := maxf(0.0, ground_size.y * 0.5 - grass_margin)
	return Vector3(
		clampf(position.x, -half_width, half_width),
		0.0,
		clampf(position.z, -half_depth, half_depth)
	)


func _get_ground_size() -> Vector2:
	var collision := ground.get_node_or_null("GroundCollision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		var shape := collision.shape as BoxShape3D
		return Vector2(shape.size.x, shape.size.z)

	var mesh_instance := ground.get_node_or_null("GroundMesh") as MeshInstance3D
	if mesh_instance and mesh_instance.mesh is BoxMesh:
		var mesh := mesh_instance.mesh as BoxMesh
		return Vector2(mesh.size.x, mesh.size.z)

	return Vector2.ZERO


func _get_protected_points() -> Array[Vector3]:
	var protected_points: Array[Vector3] = []
	var player := get_node_or_null("Player") as Node3D
	var fire_place := get_node_or_null("Props/FirePlace") as Node3D

	if player:
		protected_points.append(player.position)
	if fire_place:
		protected_points.append(fire_place.position)

	return protected_points


func _is_in_protected_area(position: Vector3, protected_points: Array[Vector3], min_distance: float = keep_clear_radius) -> bool:
	for protected_point in protected_points:
		if position.distance_to(protected_point) < min_distance:
			return true

	return false


func _build_grass_sprite(position: Vector3, rng: RandomNumberGenerator) -> Sprite3D:
	var grass := Sprite3D.new()
	grass.position = Vector3(position.x, rng.randf_range(0.75, 1.05), position.z)
	grass.scale = Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(1.2, 2.0), 1.0)
	grass.texture = GRASS_TEXTURES[rng.randi_range(0, GRASS_TEXTURES.size() - 1)]
	grass.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	grass.pixel_size = rng.randf_range(0.008, 0.014)
	return grass


func _build_tree(position: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var tree := Node3D.new()
	tree.position = position
	tree.rotation.y = rng.randf_range(0.0, TAU)

	var trunk_height := rng.randf_range(2.8, 4.5)
	var trunk_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18
	cylinder.bottom_radius = 0.26
	cylinder.height = trunk_height
	trunk_mesh.mesh = cylinder
	trunk_mesh.position.y = trunk_height * 0.5
	trunk_mesh.material_override = _make_colored_material(Color(0.42, 0.27, 0.12, 1.0), 0.95)
	tree.add_child(trunk_mesh)

	var canopy_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = rng.randf_range(1.2, 1.9)
	sphere.height = sphere.radius * 2.0
	canopy_mesh.mesh = sphere
	canopy_mesh.position.y = trunk_height + sphere.radius * 0.55
	canopy_mesh.scale = Vector3(1.15, 0.9, 1.15)
	canopy_mesh.material_override = _make_colored_material(Color(0.24, 0.56, 0.21, 1.0), 0.9)
	tree.add_child(canopy_mesh)

	return tree


func _build_rock(position: Vector3, rng: RandomNumberGenerator) -> MeshInstance3D:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	rock.mesh = mesh
	rock.position = Vector3(position.x, rng.randf_range(0.2, 0.45), position.z)
	rock.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, TAU), rng.randf_range(-0.3, 0.3))
	rock.scale = Vector3(rng.randf_range(0.6, 1.5), rng.randf_range(0.35, 0.9), rng.randf_range(0.6, 1.4))
	rock.material_override = _make_colored_material(Color(0.48, 0.49, 0.46, 1.0), 1.0)
	return rock


func _build_flower(position: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var flower := Node3D.new()
	flower.position = position
	flower.rotation.y = rng.randf_range(0.0, TAU)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.03
	stem_mesh.bottom_radius = 0.04
	stem_mesh.height = rng.randf_range(0.45, 0.75)
	stem.mesh = stem_mesh
	stem.position.y = stem_mesh.height * 0.5
	stem.material_override = _make_colored_material(Color(0.22, 0.58, 0.18, 1.0), 0.95)
	flower.add_child(stem)

	var blossom := MeshInstance3D.new()
	var blossom_mesh := SphereMesh.new()
	blossom_mesh.radius = 0.12
	blossom_mesh.height = 0.24
	blossom.mesh = blossom_mesh
	blossom.position.y = stem_mesh.height + 0.06
	blossom.scale = Vector3(1.4, 0.7, 1.4)
	var blossom_colors := [
		Color(0.98, 0.86, 0.27, 1.0),
		Color(0.91, 0.35, 0.48, 1.0),
		Color(0.88, 0.88, 0.94, 1.0),
		Color(0.48, 0.73, 0.95, 1.0)
	]
	blossom.material_override = _make_colored_material(blossom_colors[rng.randi_range(0, blossom_colors.size() - 1)], 0.75)
	flower.add_child(blossom)

	return flower


func _make_colored_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _build_enemy(position: Vector3, rng: RandomNumberGenerator) -> CharacterBody3D:
	var enemy := CharacterBody3D.new()
	enemy.script = load("res://scripts/enemy.gd")
	enemy.position = Vector3(position.x, 0.0, position.z)
	enemy.set("target", player)
	enemy.set("move_speed", rng.randf_range(5.5, 7.25))
	enemy.set("max_health", enemy_health)
	enemy.set("attack_damage", 1)
	enemy.set("attack_cooldown", 3.0)
	enemy.set("attack_range", 1.6)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.4
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.9, 0.0)
	enemy.add_child(collision)

	var body := MeshInstance3D.new()
	var torso := CapsuleMesh.new()
	torso.radius = 0.5
	torso.height = 1.8
	body.mesh = torso
	body.position = Vector3(0.0, 0.9, 0.0)
	body.scale = Vector3(1.35, 1.35, 1.35)
	body.material_override = _make_colored_material(Color(0.82, 0.19, 0.2, 1.0), 0.9)
	enemy.add_child(body)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.12
	eye_mesh.height = 0.24
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 1.35, -0.55)
	eye.scale = Vector3(1.3, 1.3, 1.3)
	eye.material_override = _make_colored_material(Color(1.0, 0.93, 0.82, 1.0), 0.25)
	enemy.add_child(eye)

	var hp_label := Label3D.new()
	hp_label.name = "HealthLabel"
	hp_label.position = Vector3(0.0, 2.25, 0.0)
	hp_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hp_label.text = "HP %d" % enemy_health
	enemy.add_child(hp_label)

	return enemy


func _on_enemy_attacked_player(damage: int) -> void:
	if is_game_over:
		return
	if is_daytime or is_player_hidden:
		return

	player_health = maxi(0, player_health - max(1, damage))
	_update_ui_labels()
	if player_health <= 0:
		_set_game_over()


func _on_enemy_defeated(_enemy: Node) -> void:
	pass


func _set_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	if wave_timer:
		wave_timer.stop()
	if player and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(false)

	for enemy_node in enemy_container.get_children():
		if enemy_node.has_method("stop_hunting"):
			enemy_node.stop_hunting()

	if game_over_panel:
		game_over_panel.visible = true


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_enemy_wave_timer_timeout() -> void:
	return
