extends CharacterBody3D
## Placeholder police car: lane-based horizontal movement with cosmetic banking.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car stays fixed at PLAYER_Z; the world scrolls. Player only moves along X.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
const PLAYER_Z: float = 4.0

# Catch reward and the cooldown after a catch (prevents instant re-scoring).
const CATCH_POINTS := 10
const CATCH_COOLDOWN := 1.5

# Bank (roll.z) limits and ramp speeds.
const BANK_MAX: float = 0.42          # ~24 degrees
const BANK_RISE: float = 10.0         # rad/s while moving laterally
const BANK_FALL: float = 6.0          # rad/s decay toward 0
const BANK_K: float = 0.13            # lateral velocity -> bank target coefficient

# Frame-rate-independent lateral smoothing.
const MOVE_SMOOTH: float = 8.0

var current_lane: int = 1
var target_lane: int = 1
var _body: Node3D
var _detect: Area3D
var _prev_x: float
var _catch_cooldown: float = 0.0

func _ready() -> void:
	_body = get_node("Body")
	_detect = get_node("DetectArea")
	_detect.area_entered.connect(_on_area_entered)
	# Start centered in the middle lane.
	var start_x: float = LANE_X[current_lane]
	global_position.x = start_x
	_prev_x = start_x

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		target_lane = clamp(target_lane - 1, 0, 3)
	elif event.is_action_pressed("move_right"):
		target_lane = clamp(target_lane + 1, 0, 3)

func _on_area_entered(area: Area3D) -> void:
	if GameState.state != "playing":
		return
	if area is TrafficCar:
		GameState.game_over()
	elif area.is_in_group("fleeing"):
		if _catch_cooldown > 0.0:
			return
		GameState.add_score(CATCH_POINTS)
		var f: Node = get_tree().get_first_node_in_group("fleeing")
		if f != null:
			f.respawn()
		_catch_cooldown = CATCH_COOLDOWN

func _physics_process(delta: float) -> void:
	if GameState.state != "playing":
		return
	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	# Keep the car fixed at the bottom of the screen; the world scrolls instead.
	global_position.z = PLAYER_Z

	var old_x: float = global_position.x
	var target_x: float = LANE_X[target_lane]

	# Smooth approach to the target lane (frame-rate independent).
	global_position.x = lerp(old_x, target_x, 1.0 - exp(-MOVE_SMOOTH * delta))

	# Lateral (sideways) velocity drives the cosmetic bank.
	var lateral_velocity: float = (global_position.x - old_x) / delta
	_prev_x = old_x

	# Bank target proportional to lateral velocity, clamped to BANK_MAX.
	var bank_target: float = clamp(lateral_velocity * BANK_K, -BANK_MAX, BANK_MAX)

	# Ramp up while moving laterally, else decay toward 0.
	var bank: float = _body.rotation.z
	if abs(lateral_velocity) > 0.01:
		bank = lerp(bank, bank_target, 1.0 - exp(-BANK_RISE * delta))
	else:
		bank = lerp(bank, 0.0, 1.0 - exp(-BANK_FALL * delta))

	# Moving right (lateral_velocity > 0) -> right side dips: negate the roll.
	_body.rotation.z = -bank

	move_and_slide()
