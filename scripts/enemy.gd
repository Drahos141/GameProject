extends CharacterBody3D

signal attacked_player(damage: int)
signal defeated(enemy: Node)

@export var move_speed: float = 6.5
@export var max_health: int = 1
@export var attack_damage: int = 1
@export var attack_range: float = 1.7
@export var attack_cooldown: float = 3.0
@export var avoidance_radius: float = 2.4
@export var avoidance_strength: float = 4.0

var target: Node3D
var is_active: bool = true
var current_health: int = 1
var attack_cooldown_remaining: float = 0.0

@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	add_to_group("enemy_hunters")
	current_health = maxi(1, max_health)
	_update_health_label()


func _physics_process(delta: float) -> void:
	if not is_active or not target or not is_instance_valid(target):
		velocity = Vector3.ZERO
		return

	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)

	var to_target := target.global_position - global_position
	var planar_offset := Vector3(to_target.x, 0.0, to_target.z)
	var distance := planar_offset.length()

	if distance <= attack_range:
		velocity = Vector3.ZERO
		_try_attack()
		return

	var direction := planar_offset / maxf(distance, 0.001)
	var avoidance := _get_avoidance_vector()
	if avoidance != Vector3.ZERO:
		direction = (direction + avoidance * avoidance_strength).normalized()
		if direction == Vector3.ZERO:
			direction = planar_offset / maxf(distance, 0.001)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = 0.0

	look_at(global_position + direction, Vector3.UP)
	move_and_slide()


func _try_attack() -> void:
	if attack_cooldown_remaining > 0.0:
		return

	attack_cooldown_remaining = attack_cooldown
	attacked_player.emit(attack_damage)


func stop_hunting() -> void:
	is_active = false
	velocity = Vector3.ZERO


func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return

	current_health = maxi(0, current_health - amount)
	_update_health_label()

	if current_health == 0:
		is_active = false
		defeated.emit(self)
		queue_free()


func _update_health_label() -> void:
	if health_label:
		health_label.text = "HP %d" % current_health


func _get_avoidance_vector() -> Vector3:
	var separation := Vector3.ZERO
	var neighbor_count := 0

	for neighbor in get_tree().get_nodes_in_group("enemy_hunters"):
		if neighbor == self:
			continue
		if not (neighbor is Node3D):
			continue

		var offset: Vector3 = global_position - neighbor.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.001 or distance > avoidance_radius:
			continue

		separation += offset.normalized() / distance
		neighbor_count += 1

	if neighbor_count == 0:
		return Vector3.ZERO

	return separation / float(neighbor_count)
