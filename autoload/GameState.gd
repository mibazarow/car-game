extends Node
## Global game state for "Patrol Rush". Registers input actions and holds
## lightweight runtime variables (speed, score, best, current state).

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

## Forward speed used by the road scroll.
var speed: float = 12.0
## Current score.
var score: int = 0
## Best score seen so far.
var best: int = 0
## Current game state: "menu" | "playing" | "paused" | "game_over".
var state: String = "playing"
