# BreadSpawner.gd (attach to your Control/Container)
extends Control

@export var spawn_interval: float = 0.75 
@export var max_concurrent: int = -1 # -1 = unlimited

# Initial motion
@export var initial_speed_min: float = 200.0
@export var initial_speed_max: float = 600.0
@export var initial_spin_min: float = -6.0
@export var initial_spin_max: float = 6.0

# Despawn (shrink & fade)
@export var lifetime_min: float = 2.0
@export var lifetime_max: float = 3.0
@export var shrink_time_min: float = 0.45
@export var shrink_time_max: float = 0.90
@export var fade_alpha: bool = true

@onready var _proto: RigidBody2D = $Bread
var _rng := RandomNumberGenerator.new()
var _spawning: bool = false   # guards against starting multiple loops

func _ready() -> void:
	_rng.randomize()
	if not is_instance_valid(_proto):
		push_warning("BreadSpawner: expected a child named 'Bread' (RigidBody2D).")
		return
	# keep the prototype hidden & inert
	_proto.visible = false
	_proto.sleeping = true

	_start_spawn_loop()

func _exit_tree() -> void:
	_spawning = false

# -------------------- spawn loop (reliable) --------------------
func _start_spawn_loop() -> void:
	if _spawning:
		return
	_spawning = true

	# clamp silly values so we don't insta-flood
	spawn_interval = max(spawn_interval, 0.05)

	_spawn_loop() # fire-and-forget

func _spawn_loop() -> void:
	while _spawning and is_inside_tree():
		if max_concurrent < 0 or _count_spawned() < max_concurrent:
			_spawn_one()
		# one spawn per interval, exactly
		await get_tree().create_timer(spawn_interval).timeout

# -------------------- one spawn --------------------
func _spawn_one() -> void:
	if not is_instance_valid(_proto):
		return

	var bread := _proto.duplicate() as RigidBody2D   # Godot 4: plain duplicate()
	if bread == null:
		return

	bread.visible = true
	bread.sleeping = false
	add_child(bread)

	# random point inside this Control's rect
	var r := get_global_rect()
	var pos := Vector2(
		_rng.randf_range(r.position.x, r.position.x + r.size.x),
		_rng.randf_range(r.position.y, r.position.y + r.size.y)
	)
	bread.global_position = pos

	# give it some motion
	var ang: float = _rng.randf() * TAU
	var spd: float = _rng.randf_range(initial_speed_min, initial_speed_max)
	bread.linear_velocity = Vector2.from_angle(ang) * spd
	bread.angular_velocity = _rng.randf_range(initial_spin_min, initial_spin_max)

	# schedule its shrink & despawn
	_schedule_despawn(bread)

# -------------------- despawn logic --------------------
func _schedule_despawn(bread: RigidBody2D) -> void:
	var life := _rng.randf_range(lifetime_min, lifetime_max)
	var shrink := _rng.randf_range(shrink_time_min, shrink_time_max)
	_despawn_after(bread, life, shrink)

func _despawn_after(bread: RigidBody2D, life: float, shrink: float) -> void:
	await get_tree().create_timer(life).timeout
	if not is_instance_valid(bread):
		return

	# stop interacting with physics
	bread.collision_layer = 0
	bread.collision_mask = 0
	bread.linear_velocity = Vector2.ZERO
	bread.angular_velocity = 0.0
	bread.sleeping = true

	# shrink (and optionally fade) to nothing
	var t := bread.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(bread, "scale", Vector2.ZERO, shrink)
	if fade_alpha:
		var target := bread.modulate
		target.a = 0.0
		t.parallel().tween_property(bread, "modulate", target, shrink)
	await t.finished
	if is_instance_valid(bread):
		bread.queue_free()

# -------------------- helpers --------------------
func _count_spawned() -> int:
	var n := 0
	for c in get_children():
		if c is RigidBody2D and c != _proto:
			n += 1
	return n
