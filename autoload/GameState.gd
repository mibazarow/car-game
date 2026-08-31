extends Node
## Global game state for "Patrol Rush". Registers input actions and holds
## lightweight runtime variables (speed, score, best, current state).

## Emitted whenever `score` changes (so the HUD can refresh).
signal score_changed

## Emitted when enough traffic cars have been overtaken to spawn a nitro pickup.
signal nitro_should_spawn

## Path (in user://) where the best score is persisted between runs.
const BEST_SAVE_PATH := "user://best.cfg"

var _engine: AudioStreamPlayer
var _nitro: AudioStreamPlayer

func _ready() -> void:
	_register_input_actions()
	_load_best()
	_size_window()
	_setup_audio()

func _setup_audio() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.stream = load("res://MODELS/engine.wav")
	_engine.volume_db = linear_to_db(0.7)
	_engine.finished.connect(func() -> void: _engine.play())
	add_child(_engine)

	_nitro = AudioStreamPlayer.new()
	_nitro.stream = load("res://MODELS/nitro.wav")
	add_child(_nitro)

func _update_engine() -> void:
	if state == "playing" or state == "paused":
		if !_engine.is_playing():
			_engine.play()
	else:
		_engine.stop()

func _register_input_actions() -> void:
	# move_left: Left arrow / A
	if !InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		var key_left := InputEventKey.new()
		key_left.keycode = KEY_LEFT
		InputMap.action_add_event("move_left", key_left)

		var key_a := InputEventKey.new()
		key_a.keycode = KEY_A
		InputMap.action_add_event("move_left", key_a)

	# move_right: Right arrow / D
	if !InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		var key_right := InputEventKey.new()
		key_right.keycode = KEY_RIGHT
		InputMap.action_add_event("move_right", key_right)

		var key_d := InputEventKey.new()
		key_d.keycode = KEY_D
		InputMap.action_add_event("move_right", key_d)

	if !InputMap.has_action("use_nitro"):
		InputMap.add_action("use_nitro")
		var key_space := InputEventKey.new()
		key_space.keycode = KEY_SPACE
		InputMap.action_add_event("use_nitro", key_space)

## Base forward speed used by the road scroll.
const BASE_SPEED := 12.0
## Points accumulated before difficulty increases by one level.
const SCORE_PER_LEVEL := 100
## Speed added per difficulty level.
const SPEED_STEP := 0.3
## Upper bound for the scroll speed.
const SPEED_MAX := 20.0
## How quickly `speed` ramps toward the difficulty target (smooth, no jumps).
const SPEED_RAMP := 1.5
## Spawn a nitro pickup after this many overtaken traffic cars.
const NITRO_EVERY := 15
## How long (seconds) nitro stays active once collected.
const NITRO_DURATION := 2.0

## Forward speed used by the road scroll.
var speed: float = BASE_SPEED
## The difficulty speed the current `speed` smoothly approaches.
var speed_target: float = BASE_SPEED
## Current score.
var score: int = 0
## Best score seen so far (persisted).
var best: int = 0
## Current game state: "menu" | "playing" | "paused" | "game_over".
var state: String = "menu"
## Difficulty level already applied (speed bumps consumed).
var _level := 0
## Number of traffic cars overtaken since the last nitro pickup spawn.
var passed_cars := 0
## Seconds of nitro remaining (drained in `_process`; enemy approaches while > 0).
var nitro_time := 0.0
## Whether one nitro pickup is stored in reserve (max one).
var nitro_ready: bool = false


## Add points to the current score and notify the HUD. Keeps `best` updated.
func add_score(points: int) -> void:
	if state != "playing":
		return
	score += points
	if score > best:
		best = score
	_update_difficulty()
	score_changed.emit()


## Called by traffic when a car is overtaken: score it, count it, and emit a
## nitro-spawn signal once `NITRO_EVERY` cars have passed.
func on_car_passed() -> void:
	if state != "playing":
		return
	add_score(1)
	passed_cars += 1
	if passed_cars >= NITRO_EVERY:
		passed_cars = 0
		nitro_should_spawn.emit()

## Store a collected nitro pickup into the reserve (max one).
func store_nitro() -> void:
	nitro_ready = true

## Start (or refresh) the nitro timer for `NITRO_DURATION` seconds.
func activate_nitro() -> void:
	if not nitro_ready:
		return
	nitro_ready = false
	nitro_time = NITRO_DURATION
	if _nitro != null:
		_nitro.stop()
		_nitro.play()

## Drain the nitro timer while playing so the fleeing car approaches.
func _process(delta: float) -> void:
	speed = lerp(speed, speed_target, 1.0 - exp(-SPEED_RAMP * delta))
	if state == "playing":
		nitro_time = maxf(0.0, nitro_time - delta)
	_update_engine()


## Slowly raise `speed` as the score climbs, one small bump per
## `SCORE_PER_LEVEL` points, capped at `SPEED_MAX`.
func _update_difficulty() -> void:
	var lvl := floori(score / float(SCORE_PER_LEVEL))
	while lvl > _level:
		speed_target = minf(speed_target + SPEED_STEP, SPEED_MAX)
		_level += 1


## Called when the run ends (crash). Freezes play and persists the record.
func game_over() -> void:
	if state == "game_over":
		return
	state = "game_over"
	if score > best:
		best = score
	_save_best()
	score_changed.emit()


## Reset the score and state for a fresh run.
func reset_run() -> void:
	score = 0
	state = "playing"
	speed = BASE_SPEED
	speed_target = BASE_SPEED
	_level = 0
	passed_cars = 0
	nitro_time = 0.0
	nitro_ready = false
	score_changed.emit()

## Start a run from the menu: reset and enter the "playing" state.
func start_game() -> void:
	reset_run()

## Toggle between "playing" and "paused".
func toggle_pause() -> void:
	if state == "playing":
		state = "paused"
	elif state == "paused":
		state = "playing"

## Resume from the pause screen back to "playing".
func resume() -> void:
	if state == "paused":
		state = "playing"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_nitro"):
		activate_nitro()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			toggle_pause()


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_SAVE_PATH) == OK:
		best = int(cfg.get_value("score", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(BEST_SAVE_PATH)


## Auto-size the window to ~75% of the screen height with a portrait aspect
## and center it on the screen. Never errors out the game if a call fails.
func _size_window() -> void:
	var screen := DisplayServer.screen_get_size()
	if screen == Vector2i.ZERO:
		return
	var screen_pos := DisplayServer.screen_get_position()
	var win_h := int(screen.y * 0.75)
	var win_w := int(win_h * 0.5625)
	var win_size := Vector2i(win_w, win_h)
	var pos := screen_pos + (screen - win_size) / 2
	DisplayServer.window_set_size(win_size)
	DisplayServer.window_set_position(pos)
