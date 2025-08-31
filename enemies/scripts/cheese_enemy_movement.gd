extends CharacterBody2D
class_name CheeseEnemyPatrol

# ── Tuning ─────────────────────────────────────────────────────────────────────
@export var move_speed: float = 350.0          # sideways speed
@export var gravity: float = 3600.0            # px/s^2
@export var max_fall_speed: float = 2400.0
@export var lookahead: float = 14.0            # how far ahead to check for edges
@export var ledge_probe_down: float = 16.0     # how far down to check for ground at the ledge
@export var turn_cooldown: float = 0.10        # little lockout to avoid jitter on corners
@export var start_dir_right: bool = false      # start facing right instead of left

# Sprite to flip (yours lives under Area2D/CollisionShape2D/Sprite2D)
@export var sprite_path: NodePath = ^"Area2D/CollisionShape2D/Sprite2D"

# ── State ──────────────────────────────────────────────────────────────────────
var _dir: int = -1                    # -1 = left, 1 = right
var _turn_lock: float = 0.0
@onready var _sprite: Sprite2D = get_node_or_null(sprite_path)

func _ready() -> void:
	_dir = 1 if start_dir_right else -1
	# Optional: ensure we're upright
	rotation = 0.0

func _physics_process(delta: float) -> void:
	# gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
	else:
		# keep tiny floor jitter down
		if velocity.y > 0.0:
			velocity.y = 0.0

	# patrol sideways
	velocity.x = _dir * move_speed

	# decide if we should turn (wall or ledge)
	if _turn_lock > 0.0:
		_turn_lock -= delta
	else:
		if _hit_wall() or _at_ledge():
			_dir *= -1
			_turn_lock = turn_cooldown

	# move
	move_and_slide()

	# flip sprite (your art faces right by default)
	if _sprite and abs(velocity.x) > 1.0:
		_sprite.flip_h = (velocity.x < 0.0)

# ── Probes ─────────────────────────────────────────────────────────────────────
func _hit_wall() -> bool:
	return is_on_wall()

func _at_ledge() -> bool:
	# Check from a point a little ahead of us: if moving a bit DOWN would NOT collide,
	# there’s no ground → ledge → turn around.
	var t: Transform2D = global_transform
	t.origin += Vector2(_dir * lookahead, 0.0)
	var will_collide_down: bool = test_move(t, Vector2(0.0, ledge_probe_down))
	var has_ground_ahead: bool = will_collide_down
	return not has_ground_ahead
