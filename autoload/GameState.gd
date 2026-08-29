extends Node
## Global game state for "Patrol Rush". Registers input actions and holds
## lightweight runtime variables (speed, score, best, current state).

## Emitted whenever `score` changes (so the HUD can refresh).
signal score_changed

## Path (in user://) where the best score is persisted between runs.
const BEST_SAVE_PATH := "user://best.cfg"

func _ready() -> void:
	_register_input_actions()
	_load_best()
	_size_window()

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

## Base forward speed used by the road scroll.
const BASE_SPEED := 12.0
## Points accumulated before difficulty increases by one level.
const SCORE_PER_LEVEL := 500
## Speed added per difficulty level.
const SPEED_STEP := 0.2
## Upper bound for the scroll speed.
const SPEED_MAX := 20.0

## Forward speed used by the road scroll.
var speed: float = BASE_SPEED
## Current score.
var score: int = 0
## Best score seen so far (persisted).
var best: int = 0
## Current game state: "menu" | "playing" | "paused" | "game_over".
var state: String = "menu"
## Difficulty level already applied (speed bumps consumed).
var _level := 0


## Add points to the current score and notify the HUD. Keeps `best` updated.
func add_score(points: int) -> void:
	if state != "playing":
		return
	score += points
	if score > best:
		best = score
	_update_difficulty()
	score_changed.emit()


## Slowly raise `speed` as the score climbs, one small bump per
## `SCORE_PER_LEVEL` points, capped at `SPEED_MAX`.
func _update_difficulty() -> void:
	var lvl := floori(score / float(SCORE_PER_LEVEL))
	while lvl > _level:
		speed = minf(speed + SPEED_STEP, SPEED_MAX)
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
	_level = 0
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
