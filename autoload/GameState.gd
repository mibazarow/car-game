extends Node
## Global game state for "Patrol Rush". Registers input actions and holds
## lightweight runtime variables (speed, score, best, current state).

## Emitted whenever `score` changes (so the HUD can refresh).
signal score_changed

## Emitted when enough traffic cars have been overtaken to spawn a nitro pickup.
signal nitro_should_spawn

## Emitted when enough traffic cars have been overtaken to spawn a rocket pickup.
signal rocket_should_spawn

func _ready() -> void:
	_register_input_actions()

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

	if !InputMap.has_action("fire_rocket"):
		InputMap.add_action("fire_rocket")
		var key_enter := InputEventKey.new()
		key_enter.keycode = KEY_ENTER
		InputMap.action_add_event("fire_rocket", key_enter)

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
## Spawn a rocket pickup this many cars AFTER a nitro pickup spawns.
const ROCKET_AFTER_NITRO := 4

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
## Number of traffic cars overtaken since the last rocket pickup spawn.
var rocket_passed_cars := 0
## Whether one rocket is stored in reserve (max one).
var rocket_ready: bool = false
## True if the last run ended in a WIN (player destroyed the enemy).
var victory: bool = false
## Whether a rocket is pending to spawn (armed after a nitro spawns).
var rocket_armed := false


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
		rocket_armed = true
		rocket_passed_cars = 0
	elif rocket_armed:
		rocket_passed_cars += 1
		if rocket_passed_cars >= ROCKET_AFTER_NITRO:
			rocket_armed = false
			rocket_should_spawn.emit()

## Store a collected nitro pickup into the reserve (max one).
func store_nitro() -> void:
	nitro_ready = true

## Store a collected rocket into the reserve (max one).
func store_rocket() -> void:
	rocket_ready = true

## Try to consume the stored rocket. Returns true (and clears the reserve) if
## one was available; false if none stored.
func consume_rocket() -> bool:
	if not rocket_ready:
		return false
	rocket_ready = false
	return true

## Start (or refresh) the nitro timer for `NITRO_DURATION` seconds.
func activate_nitro() -> void:
	if not nitro_ready:
		return
	nitro_ready = false
	nitro_time = NITRO_DURATION
	AudioManager.play_nitro()

## Drain the nitro timer while playing so the fleeing car approaches.
func _process(delta: float) -> void:
	speed = lerp(speed, speed_target, 1.0 - exp(-SPEED_RAMP * delta))
	if state == "playing":
		nitro_time = maxf(0.0, nitro_time - delta)


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
	SaveManager.save_best(best)
	score_changed.emit()

## Called when the player destroys the fleeing enemy: a win. Freezes play and
## persists the record.
func win() -> void:
	if state == "game_over":
		return
	victory = true
	state = "game_over"
	if score > best:
		best = score
	SaveManager.save_best(best)
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
	rocket_passed_cars = 0
	rocket_ready = false
	victory = false
	rocket_armed = false
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
