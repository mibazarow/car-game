extends Area3D
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
# Yaw (rotation.y): the nose turns toward the lane-change direction.
const YAW_MAX: float = 0.6            # ~34 degrees
const YAW_K: float = 0.09             # lateral velocity -> yaw target coefficient

# Frame-rate-independent lateral smoothing.
const MOVE_SMOOTH: float = 8.0

# Nitro: the player surges FORWARD (up the screen) by this many world units
# (~1/3 of the ~24-unit visible height) over the ~2s nitro duration.
const NITRO_FORWARD: float = 8.0
# Smoothing factor for the forward surge / return (1 - exp(-k*dt)); k≈1.8
# reaches ~97% of the way in ~2s.
const NITRO_LERP: float = 1.8

var current_lane: int = 1
var target_lane: int = 1
var _body: Node3D
var _detect: Area3D
var _prev_x: float
var _yaw_cur: float = 0.0

func _ready() -> void:
	_body = get_node("CarModel")
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
	# Nitro pickup is collected in _physics_process by checking lane alignment.

func _physics_process(delta: float) -> void:
	if GameState.state != "playing":
		return
	# Collision root stays pinned at the player's row; only the visual Body
	# surges forward during nitro. So the boost reads clearly but the car never
	# phases through traffic (and doesn't crash from the surge).
	global_position.z = PLAYER_Z
	var body_target: float = -NITRO_FORWARD if GameState.nitro_time > 0.0 else 0.0
	_body.position.z = lerp(_body.position.z, body_target, 1.0 - exp(-NITRO_LERP * delta))

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

	# Yaw: the nose turns toward the lane-change direction (moving right -> turn
	# right = negative rotation.y). Ramps with the bank, decays to straight.
	var yaw_target: float = clamp(lateral_velocity * YAW_K, -YAW_MAX, YAW_MAX)
	var yaw: float = _yaw_cur
	if abs(lateral_velocity) > 0.01:
		yaw = lerp(yaw, -yaw_target, 1.0 - exp(-BANK_RISE * delta))
	else:
		yaw = lerp(yaw, 0.0, 1.0 - exp(-BANK_FALL * delta))
	_yaw_cur = yaw
	_body.rotation.y = yaw
	_detect.rotation.z = _body.rotation.z
	_detect.rotation.y = _body.rotation.y

	_collect_nitro()

## Collect a nitro pickup only when it has reached the player's row AND the
## player is on the pickup's lane (like picking a pickup up off the road).
func _collect_nitro() -> void:
	for node in get_tree().get_nodes_in_group("nitro"):
		var pickup := node as NitroPickup
		if pickup == null or not pickup.is_active():
			continue
		var on_row: bool = absf(pickup.position.z - global_position.z) < 2.0
		var on_lane: bool = absf(global_position.x - LANE_X[pickup.lane]) < 0.7
		if on_row and on_lane:
			if GameState.nitro_ready:
				continue
			pickup.deactivate()
			GameState.store_nitro()
			return
