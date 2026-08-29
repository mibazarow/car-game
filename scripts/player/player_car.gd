extends CharacterBody3D
## Placeholder police car: lane-based horizontal movement with cosmetic banking.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car stays fixed at PLAYER_Z; the world scrolls. Player only moves along X.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
const PLAYER_Z: float = 4.0

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
var _prev_x: float

func _ready() -> void:
	_body = get_node("Body")
	# Start centered in the middle lane.
	var start_x: float = LANE_X[current_lane]
	global_position.x = start_x
	_prev_x = start_x

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		target_lane = clamp(target_lane - 1, 0, 3)
	elif event.is_action_pressed("move_right"):
		target_lane = clamp(target_lane + 1, 0, 3)

func _physics_process(delta: float) -> void:
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
