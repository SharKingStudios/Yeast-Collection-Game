# res://sound_controller.gd
extends Node

# ── Buses used (adjust to your project) ────────────────────────────────────────
const BUS_SFX:   String = "SFX"
const BUS_UI:    String = "UI"
const BUS_MUSIC: String = "Music"

# ── Assign your sounds in the Inspector (preloaded defaults) ───────────────────
@export_group("Player SFX")
@export var sfx_jump: AudioStream          = preload("res://sounds/sfx/jump.wav")
@export var sfx_double_jump: AudioStream   = preload("res://sounds/sfx/jumpDouble.wav")
@export var sfx_dash: AudioStream          = preload("res://sounds/sfx/jump.wav")
@export var sfx_wall_jump: AudioStream     = preload("res://sounds/sfx/jumpWall.wav")
@export var sfx_land: AudioStream          = preload("res://sounds/sfx/land.wav")
@export var sfx_slide_start: AudioStream   = preload("res://sounds/sfx/slideStart.wav")
@export var sfx_slide_end: AudioStream     = preload("res://sounds/sfx/slideEnd.wav")

@export_group("Looping Slide Grind")
#@export var sfx_grind_loop: AudioStream    = preload("res://sounds/sfx/slideLoop.wav")
@export var grind_min_pitch: float = 0.9
@export var grind_max_pitch: float = 1.3
@export var grind_min_speed: float = 400.0
@export var grind_max_speed: float = 2400.0
@export var grind_min_db: float    = -18.0
@export var grind_max_db: float    = -18.0
@export var grind_bus: String      = BUS_SFX
@export var grind_min_cut_hz: float = 600.0     # darker at low speed
@export var grind_max_cut_hz: float = 700.0    # brighter at high speed
@export var grind_q: float = 0.35               # 0.2–0.7 sounds “gritty”

# ── Internals ──────────────────────────────────────────────────────────────────
var _grind_player: AudioStreamPlayer
var _grind_active: bool = false

# Generator bits
var _grind_gen: AudioStreamGenerator
var _grind_pb: AudioStreamGeneratorPlayback
var _grind_sr: float = 48000.0
var _gain: float = 0.0
var _gain_target: float = 0.0
var _cut_target: float = 2000.0
var _svf_low: float = 0.0
var _svf_band: float = 0.0


@export_group("Pickups / Damage / UI")
@export var sfx_yeast_collect: AudioStream = preload("res://sounds/sfx/yeastCollect.wav")
@export var sfx_player_hurt: AudioStream   = preload("res://sounds/sfx/playerHurt.wav")
@export var sfx_ui_click: AudioStream      = preload("res://sounds/sfx/buttonSelect.wav")
@export var sfx_ui_hover: AudioStream      = preload("res://sounds/sfx/uiHover.wav")
@export var sfx_ui_back: AudioStream       = preload("res://sounds/sfx/buttonSelect.wav")
@export var sfx_ui_play_button: AudioStream= preload("res://sounds/sfx/gameStart.wav")

@export_group("Enemies")
@export var sfx_enemy_death: AudioStream = preload("res://sounds/sfx/enemyDeath.wav")

@export_group("Music (Menu / Game)")
@export var music_bus: String = BUS_MUSIC
@export var music_menu: Array[AudioStream] = [
	preload("res://sounds/songs/menuMusic-_8_Bit_Surf_-_FesliyanStudios.com_-_David_Renda.mp3"),
]
@export var music_game: Array[AudioStream] = [
	preload("res://sounds/songs/gameplayMusic-_8_Bit_Retro_Funk_-_www.FesliyanStudios.com_David_Renda.mp3"),
	#preload(),
]

# ── Music internals ───────────────────────────────────────────────────────
var _music_player: AudioStreamPlayer = null
var _music_index := 0

func _ready() -> void:
	# Ensure this singleton processes every frame (AutoLoad friendly)
	set_process(true)  # works in Godot 3 & 4

	# Grind player (procedural)
	_grind_player = AudioStreamPlayer.new()
	_grind_player.bus = grind_bus
	add_child(_grind_player)

	_grind_gen = AudioStreamGenerator.new()
	_grind_gen.mix_rate = _grind_sr
	_grind_gen.buffer_length = 0.25
	_grind_player.stream = _grind_gen
	_grind_player.autoplay = false

	# Music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	_music_player.autoplay = false
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	# Scene-tree hooks (as a true singleton, not attached to scene)
	get_tree().node_added.connect(_on_node_added)

	if get_tree().has_signal("current_scene_changed"):
		get_tree().current_scene_changed.connect(_on_current_scene_changed)
	elif get_tree().has_signal("scene_changed"):
		get_tree().scene_changed.connect(_on_current_scene_changed)

	# Defer: first scene may not be assigned yet when this AutoLoad _ready() runs
	call_deferred("_after_boot")

func _after_boot() -> void:
	_scan_existing(get_tree().root)
	_auto_play_for_scene()  # start menu/game music automatically if groups are set

func _on_node_added(n: Node) -> void:
	_try_connect_player(n)
	_try_connect_enemy(n)
	_try_connect_button(n)

func _scan_existing(root: Node) -> void:
	for n in root.get_children():
		_try_connect_player(n)
		_try_connect_enemy(n)
		_try_connect_button(n)
		_scan_existing(n)

# ── Player hookups (signal-based, no class inspection) ─────────────────────────
func _try_connect_player(n: Node) -> void:
	_connect_if_has(n, "jumped",        Callable(self, "_on_player_jumped"))
	_connect_if_has(n, "double_jumped", Callable(self, "_on_player_double_jumped"))
	_connect_if_has(n, "dashed",        Callable(self, "_on_player_dashed"))
	_connect_if_has(n, "wall_jumped",   Callable(self, "_on_player_wall_jumped"))
	_connect_if_has(n, "landed",        Callable(self, "_on_player_landed"))
	_connect_if_has(n, "slid_started",  Callable(self, "_on_player_slid_started"))
	_connect_if_has(n, "slid_ended",    Callable(self, "_on_player_slid_ended"))
	_connect_if_has(n, "speed_changed", Callable(self, "_on_player_speed_changed"))


func _try_connect_enemy(n: Node) -> void:
	if n.has_signal("died") and not n.is_connected("died", Callable(self, "_on_enemy_died")):
		n.connect("died", Callable(self, "_on_enemy_died"))
	if n.has_signal("yeastcollected") and not n.is_connected("died", Callable(self, "_on_yeast_collected")):
		n.connect("yeastcollected", Callable(self, "_on_yeast_collected"))

# ── Button hookups ─────────────────────────────────────────────────────────────
func _try_connect_button(n: Node) -> void:
	if n is Button:
		var b: Button = n
		if not b.is_connected("pressed", Callable(self, "_on_button_pressed")):
			b.pressed.connect(Callable(self, "_on_button_pressed").bind(b))
		if not b.is_connected("mouse_entered", Callable(self, "_on_button_hovered")):
			b.mouse_entered.connect(Callable(self, "_on_button_hovered").bind(b))

func _on_button_pressed(b: Button) -> void:
	var name_lc: String = b.name.to_lower()
	if name_lc.contains("play") and sfx_ui_play_button:
		_oneshot(sfx_ui_play_button, BUS_UI)
	elif sfx_ui_click:
		_oneshot(sfx_ui_click, BUS_UI)

func _on_button_hovered(b: Button) -> void:
	if sfx_ui_hover:
		_oneshot(sfx_ui_hover, BUS_UI)

# ── Player SFX handlers ────────────────────────────────────────────────────────
func _on_player_jumped() -> void:
	if sfx_jump: _oneshot(sfx_jump)

func _on_player_double_jumped() -> void:
	if sfx_double_jump: _oneshot(sfx_double_jump)

func _on_player_dashed() -> void:
	if sfx_dash: _oneshot(sfx_dash)

func _on_player_wall_jumped() -> void:
	if sfx_wall_jump: _oneshot(sfx_wall_jump)

func _on_player_landed() -> void:
	if sfx_land: _oneshot(sfx_land)

func _on_player_slid_started() -> void:
	if sfx_slide_start: _oneshot(sfx_slide_start)
	_start_grind()

func _on_player_slid_ended() -> void:
	if sfx_slide_end: _oneshot(sfx_slide_end)
	_stop_grind()

func _on_player_speed_changed(speed: float) -> void:
	if not _grind_active:
		return
	var denom: float = max(1.0, (grind_max_speed - grind_min_speed))
	var t: float = clamp((speed - grind_min_speed) / denom, 0.0, 1.0)

	# Brightness (filter cutoff)
	_cut_target = lerp(grind_min_cut_hz, grind_max_cut_hz, t)

	# Loudness (dB → linear)
	var vol_db: float = lerp(grind_min_db, grind_max_db, t)
	_gain_target = pow(10.0, vol_db / 20.0)


# ── Public API ─────────────────────────────────────────────────────────────────
func play_yeast_collected() -> void:
	if sfx_yeast_collect: _oneshot(sfx_yeast_collect)

func play_player_hurt() -> void:
	if sfx_player_hurt: _oneshot(sfx_player_hurt)

func play_button_click() -> void:
	if sfx_ui_click: _oneshot(sfx_ui_click, BUS_UI)

func play_button_back() -> void:
	if sfx_ui_back: _oneshot(sfx_ui_back, BUS_UI)

func play_play_button() -> void:
	if sfx_ui_play_button: _oneshot(sfx_ui_play_button, BUS_UI)

func _on_enemy_died() -> void:
	if sfx_enemy_death: _oneshot(sfx_enemy_death)

func _on_yeast_collected() -> void:
	if sfx_yeast_collect: _oneshot(sfx_yeast_collect)

# ── Helpers ────────────────────────────────────────────────────────────────────
func _oneshot(stream: AudioStream, bus: String = BUS_SFX, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if stream == null:
		return
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = bus
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = vol_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _process(_delta: float) -> void:
	if not _grind_active or _grind_pb == null:
		return

	# Smooth gain toward target (simple one-pole)
	_gain += (_gain_target - _gain) * 0.05

	var frames_to_write: int = _grind_pb.get_frames_available()
	if frames_to_write <= 0:
		return

	# Precompute SVF “f” from target cutoff
	var cut: float = clamp(_cut_target, 60.0, 12000.0)
	var f: float = 2.0 * sin(PI * cut / _grind_sr)
	f = clamp(f, 0.0, 1.0)
	var q: float = clamp(grind_q, 0.05, 1.2)

	for i in range(frames_to_write):
		# White noise [-1,1]
		var x: float = (randf() * 2.0) - 1.0

		# State-variable filter (band-pass)
		var high: float = x - _svf_low - q * _svf_band
		_svf_band += f * high
		_svf_low  += f * _svf_band
		var band: float = _svf_band

		var s: float = band * _gain

		# Just push a Vector2 sample (left,right)
		_grind_pb.push_frame(Vector2(s, s))

func _start_grind() -> void:
	if _grind_active:
		return
	print("[Sound] Start grind (proc)")
	_svf_low = 0.0
	_svf_band = 0.0
	_gain = 0.0
	_gain_target = pow(10.0, grind_min_db / 20.0)
	_cut_target = grind_min_cut_hz

	_grind_player.play()
	_grind_pb = _grind_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_grind_active = true

func _stop_grind() -> void:
	if not _grind_active:
		return
	print("[Sound] Stop grind (proc)")
	# Short fade-out; let _process drain buffer
	_gain_target = 0.0
	await get_tree().create_timer(0.15).timeout
	_grind_active = false
	if _grind_player.playing:
		_grind_player.stop()
	_grind_pb = null

func _connect_if_has(n: Node, sig: String, target: Callable) -> void:
	if n.has_signal(sig):
		if not n.is_connected(sig, target):
			var ok := n.connect(sig, target)
			if ok == OK:
				print("[Sound] Connected ", n.name, " -> ", sig)
			else:
				push_warning("[Sound] Failed to connect ", n.name, " -> ", sig, " (code ", ok, ")")
				
func _force_loop_on(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		# loop_begin/loop_end 0 uses full clip; set markers if you need seamless loop points
		stream.loop_begin = 0
		stream.loop_end = 0


# ── Music helpers ─────────────────────────────────────────────────────────
func _force_loop_on_music(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = 0

func _play_playlist(list: Array[AudioStream]) -> void:
	if list.is_empty(): return
	_music_index = clamp(_music_index, 0, list.size() - 1)
	var s: AudioStream = list[_music_index]
	_force_loop_on_music(s)
	_music_player.stream = s
	_music_player.play()

func play_menu_music() -> void:
	_music_index = 0
	_play_playlist(music_menu)

func play_game_music() -> void:
	_music_index = 0
	_play_playlist(music_game)

func stop_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()

func _on_music_finished() -> void:
	var list := music_menu if _music_player.stream in music_menu else music_game
	if list.is_empty(): return
	_music_index = (_music_index + 1) % list.size()
	_play_playlist(list)

func _on_current_scene_changed(_new_scene: Node) -> void:
	stop_music()          # stop when changing scenes
	_auto_play_for_scene() # then start appropriate playlist

func _auto_play_for_scene() -> void:
	var cs := get_tree().current_scene
	if cs == null: return
	if cs.is_in_group("menu"):
		play_menu_music()
	elif cs.is_in_group("game"):
		play_game_music()
