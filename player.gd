extends CharacterBody2D
class_name Player

# ── Signals ─────────────────────────────────────────────────────────────────────
signal jumped
signal double_jumped
signal dashed
signal wall_jumped
signal landed
signal slid_started
signal slid_ended
signal state_changed(previous: String, current: String)
signal speed_changed(speed: float)

# ── Node references ────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _jump_fx: Node = $JumpParticles
@onready var _slide_fx: Node = $SlideParticles

# ── Visual tunables ────────────────────────────────────────────────────────────
@export var face_by_velocity_threshold: float = 40.0
@export var slide_squish_scale: Vector2 = Vector2(0.2, 0.1) # wider, shorter
@export var normal_scale: Vector2 = Vector2(0.15, 0.15)
@export var squish_in_time: float = 0.08
@export var squish_out_time: float = 0.10
@export var double_jump_burst_time: float = 0.12

# ── Movement tunables ──────────────────────────────────────────────────────────
@export var max_run_speed: float = 1500.0
@export var ground_accel: float = 9000.0
@export var air_accel: float = 6000.0
@export var ground_friction: float = 7000.0
@export var air_friction: float = 1200.0

@export var jump_velocity: float = -3000.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var cut_jump_factor: float = 0.45

@export var allow_double_jump: bool = true
@export var double_jump_impulse: float = -2500.0
@export var double_dash_speed_add: float = 1800.0
@export var double_dash_min_dir_speed: float = 400.0
@export var double_dash_up_assist: float = -200.0

@export var allow_wall_jump: bool = true
@export var wall_slide_speed: float = 360.0
@export var wall_jump_push: float = 1600.0
@export var wall_jump_up: float = -2800.0
@export var wall_stick_time: float = 0.08
@export var wall_dir_input_threshold: float = 0.3

# ── Slide (ground) + Slam (air) ────────────────────────────────────────────────
@export var allow_slide: bool = true
@export var slide_boost_speed: float = 2400.0      # ≫ run speed for clear feeling
@export var slide_time: float = 0.90
@export var slide_friction: float = 500.0         # slide decays by this per second
@export var slide_cooldown: float = 0.15
@export var slide_cancel_on_opposite: bool = true
@export var slide_cancel_input: float = 0.7

@export var allow_air_slam: bool = true
@export var slam_instant_down_speed: float = 3200.0  # set immediate downward speed
@export var slam_extra_grav_mult: float = 2.0        # extra gravity while sliding in air

# ── Private state ───────────────────────────────────────────────────────────────
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _last_on_floor: bool = false
var _last_speed_report: float = 0.0
var _wall_stick_timer: float = 0.0
var _current_state: String = "idle"
var _prev_state: String = "idle"
var _last_move_dir: float = 0.0

# jump accounting (single source of truth)
var _jumps_used: int = 0  # 0 = none, 1 = first jump, 2 = double used

# slide/slam state
var _is_sliding: bool = false
var _slide_timer: float = 0.0
var _slide_cooldown_timer: float = 0.0
var _slide_dir: int = 1
var _is_air_slam: bool = false

func _ready() -> void:
	emit_signal("slid_ended")
	_update_fsm()
	# ensure visuals are in a sane default state
	if is_instance_valid(_jump_fx) and "emitting" in _jump_fx:
		_jump_fx.emitting = false
	if is_instance_valid(_slide_fx) and "emitting" in _slide_fx:
		_slide_fx.emitting = false
	_sprite.scale = normal_scale

func _physics_process(delta: float) -> void:
	# Snapshot BEFORE movement to detect transitions after move_and_slide()
	var was_on_floor: bool = is_on_floor()

	# ── Gravity ────────────────────────────────────────────────────────────────
	if not is_on_floor():
		var g: Vector2 = get_gravity() * delta
		if _is_sliding and _is_air_slam and allow_air_slam and slam_extra_grav_mult > 0.0:
			g *= slam_extra_grav_mult
		velocity += g

	# ── Timers ────────────────────────────────────────────────────────────────
	if _coyote_timer > 0.0: _coyote_timer -= delta
	if _jump_buffer_timer > 0.0: _jump_buffer_timer -= delta
	if _wall_stick_timer > 0.0: _wall_stick_timer -= delta
	if _slide_timer > 0.0: _slide_timer -= delta
	if _slide_cooldown_timer > 0.0: _slide_cooldown_timer -= delta

	# ── Input ─────────────────────────────────────────────────────────────────
	var left_right: float = Input.get_axis("left", "right")
	var jump_pressed: bool = Input.is_action_just_pressed("jump")
	var jump_released: bool = Input.is_action_just_released("jump")
	var down_pressed: bool = Input.is_action_just_pressed("down")

	if abs(left_right) > 0.05:
		_last_move_dir = sign(left_right)

	# buffer only for ground/wall jumps
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time

	# ── SLIDE / SLAM ─────────────────────────────────────────────────────────
	if allow_slide:
		# start slide on ground, or slam in air
		if down_pressed and _slide_cooldown_timer <= 0.0 and not _is_sliding:
			if is_on_floor():
				_start_slide(false)
			elif allow_air_slam:
				_start_slide(true)  # air slam shares slide state for simplicity
		if _is_sliding:
			# decay horizontal speed while sliding (regardless of ground/air)
			var spd: float = abs(velocity.x)
			spd = move_toward(spd, 0.0, slide_friction * delta)
			velocity.x = _slide_dir * spd

			# end conditions
			if _slide_timer <= 0.0:
				_end_slide()
			elif slide_cancel_on_opposite and abs(left_right) >= slide_cancel_input and sign(left_right) == -_slide_dir:
				_end_slide()

	# ── Horizontal control (disabled while sliding) ───────────────────────────
	if not _is_sliding:
		var target_speed: float = left_right * max_run_speed
		var accel: float = ground_accel if is_on_floor() else air_accel
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
		if abs(left_right) <= 0.05:
			var fric: float = ground_friction if is_on_floor() else air_friction
			velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# ── Wall slide detection ─────────────────────────────────────────────────
	var on_wall: bool = is_on_wall()
	var pressing_into_wall: bool = false
	if on_wall:
		var wall_norm_x: float = get_wall_normal().x
		if abs(left_right) > wall_dir_input_threshold and sign(left_right) == -sign(wall_norm_x):
			pressing_into_wall = true
	var should_wall_slide: bool = allow_wall_jump and on_wall and not is_on_floor() and pressing_into_wall
	if should_wall_slide:
		_wall_stick_timer = wall_stick_time
		if velocity.y > wall_slide_speed:
			velocity.y = wall_slide_speed

	# ── Jumps ────────────────────────────────────────────────────────────────
	var can_ground_style_jump: bool = (is_on_floor() or _coyote_timer > 0.0)

	# fresh press: resolve in priority order
	if jump_pressed:
		if can_ground_style_jump:
			_do_ground_jump()
			_jump_buffer_timer = 0.0
		elif should_wall_slide:
			_do_wall_jump()
			_jump_buffer_timer = 0.0
		elif allow_double_jump and not is_on_floor() and _jumps_used == 1:
			_do_double_jump_with_dash()
			_jump_buffer_timer = 0.0
	# buffered (no buffered double jump)
	elif _jump_buffer_timer > 0.0:
		if can_ground_style_jump:
			_do_ground_jump()
			_jump_buffer_timer = 0.0
		elif should_wall_slide:
			_do_wall_jump()
			_jump_buffer_timer = 0.0

	# variable jump height
	if jump_released and velocity.y < 0.0:
		velocity.y *= cut_jump_factor

	# ── Move (updates floor/wall state) ──────────────────────────────────────
	move_and_slide()

	# ── Floor transitions AFTER movement (fixes missed landing) ─────────────
	if is_on_floor() and not was_on_floor:
		emit_signal("landed")
		_jumps_used = 0
		_wall_stick_timer = 0.0
		if _is_sliding and _is_air_slam:
			_is_air_slam = false
	elif not is_on_floor() and was_on_floor:
		_coyote_timer = coyote_time

	# ── Visuals / state feedback ────────────────────────────────────────────
	_update_sprite_facing(left_right)
	_report_speed_change()
	_update_fsm()
	_last_on_floor = is_on_floor()

# ── Jump helpers ────────────────────────────────────────────────────────────────
func _do_ground_jump() -> void:
	if _is_sliding: _end_slide()
	velocity.y = jump_velocity
	_jumps_used = 1
	emit_signal("jumped")

func _do_double_jump_with_dash() -> void:
	_jumps_used = 2
	# vertical oomph (optional)
	if double_jump_impulse != 0.0:
		velocity.y = double_jump_impulse

	# dash direction from intent/speed
	var dir: float = 0.0
	if abs(_last_move_dir) > 0.0:
		dir = _last_move_dir
	elif abs(velocity.x) > 10.0:
		dir = sign(velocity.x)
	else:
		dir = 1.0

	# seed base speed if nearly still
	if abs(velocity.x) < double_dash_min_dir_speed:
		velocity.x = dir * double_dash_min_dir_speed

	# add burst
	velocity.x += dir * double_dash_speed_add

	# optional up assist so it doesn't feel too flat
	if double_dash_up_assist != 0.0 and velocity.y > double_dash_up_assist:
		velocity.y = double_dash_up_assist

	# FX: quick burst of jump particles
	_emit_burst(_jump_fx, double_jump_burst_time)

	emit_signal("double_jumped")
	emit_signal("dashed")

func _do_wall_jump() -> void:
	var wall_normal: Vector2 = get_wall_normal()
	if wall_normal == Vector2.ZERO:
		wall_normal = Vector2(-_last_move_dir, 0).normalized()
	velocity.x = wall_normal.x * wall_jump_push
	velocity.y = wall_jump_up
	# treat as first jump → allow double afterward
	_jumps_used = 1
	emit_signal("wall_jumped")

# ── Slide / Slam helpers ───────────────────────────────────────────────────────
func _start_slide(air_slam: bool) -> void:
	_is_sliding = true
	_is_air_slam = air_slam
	_slide_timer = slide_time
	_slide_cooldown_timer = slide_cooldown

	# decide horizontal direction from intent/speed
	var dir_from_input: int = (1 if _last_move_dir >= 0.0 else -1)
	var dir_from_speed: int = (1 if velocity.x >= 0.0 else -1)
	_slide_dir = dir_from_input if abs(_last_move_dir) > 0.0 else dir_from_speed

	# clear, strong speed difference (even in air)
	var seed_speed: float = max(abs(velocity.x), slide_boost_speed)
	velocity.x = _slide_dir * seed_speed

	# if in air and slamming, force a big downward speed
	if air_slam and allow_air_slam:
		velocity.y = max(velocity.y, slam_instant_down_speed)

	# visuals: squish + slide particles
	_squish_sprite(true)
	if is_instance_valid(_slide_fx) and "emitting" in _slide_fx:
		_slide_fx.emitting = true

	emit_signal("slid_started")

func _end_slide() -> void:
	if _is_sliding:
		_is_sliding = false
		_is_air_slam = false
		_squish_sprite(false)
		if is_instance_valid(_slide_fx) and "emitting" in _slide_fx:
			_slide_fx.emitting = false
		emit_signal("slid_ended")

# ── Visual helpers ─────────────────────────────────────────────────────────────
func _update_sprite_facing(input_dir: float) -> void:
	# Prefer velocity for snappy facing; fall back to last intent if slow.
	var face_dir: float = 0.0
	if abs(velocity.x) >= face_by_velocity_threshold:
		face_dir = sign(velocity.x)
	elif abs(input_dir) >= 0.05:
		face_dir = sign(input_dir)
	elif abs(_last_move_dir) > 0.0:
		face_dir = _last_move_dir

	# Sprite faces right by default → flip when facing left
	if face_dir != 0.0:
		_sprite.flip_h = (face_dir < 0.0)

func _squish_sprite(slide_on: bool) -> void:
	if not is_instance_valid(_sprite):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if slide_on:
		tween.tween_property(_sprite, "scale", slide_squish_scale, squish_in_time)
	else:
		tween.tween_property(_sprite, "scale", normal_scale, squish_out_time)

func _emit_burst(node: Node, duration: float) -> void:
	if not is_instance_valid(node):
		return
	if "emitting" in node:
		node.emitting = true
		# turn off shortly after
		await get_tree().create_timer(max(0.01, duration)).timeout
		if is_instance_valid(node):
			node.emitting = false

# ── FSM / feedback ─────────────────────────────────────────────────────────────
func _update_fsm() -> void:
	var s := "idle"
	if _is_sliding:
		s = "slide"
	elif not is_on_floor():
		if is_on_wall() and _wall_stick_timer > 0.0:
			s = "wall_slide"
		elif velocity.y < 0.0:
			s = "jump"
		else:
			s = "fall"
	else:
		if abs(velocity.x) > 40.0:
			s = "run"
	if s != _current_state:
		_prev_state = _current_state
		_current_state = s
		emit_signal("state_changed", _prev_state, _current_state)

func _report_speed_change() -> void:
	var spd: float = velocity.length()
	if abs(spd - _last_speed_report) > 50.0:
		_last_speed_report = spd
		emit_signal("speed_changed", spd)
