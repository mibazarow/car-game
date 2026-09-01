extends Area3D
const RocketScene := preload("res://scenes/Rocket.tscn")
## Placeholder police car: lane-based horizontal movement with cosmetic banking.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car stays fixed at PLAYER_Z; the world scrolls. Player only moves along X.
## Cosmetic roll banking and nose yaw come from CarBank (shared with traffic/enemy).

# Lane center X positions (lanes 0..3, left -> right) are provided by RoadConfig.
const PLAYER_Z: float = 4.0

# Bank (roll.z) / yaw (rotation.y) scaling coefficients (targets computed in CarBank).
const BANK_K: float = 0.13            # lateral velocity -> bank target coefficient
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

func _ready() -> void:
	_body = get_node("CarModel")
	_detect = get_node("DetectArea")
	_detect.area_entered.connect(_on_area_entered)
	# Start centered in the middle lane.
	var start_x: float = RoadConfig.lane_center(current_lane)
	global_position.x = start_x

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire_rocket"):
		_try_fire_rocket()
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
	# During nitro the whole car (visual + collision hitbox) surges forward
	# together, so the hitbox is where the car is — no invincibility, no
	# phasing through traffic; you still crash if a car is in your path.
	global_position.z = PLAYER_Z
	var body_target: float = -NITRO_FORWARD if GameState.nitro_time > 0.0 else 0.0
	_body.position.z = lerp(_body.position.z, body_target, 1.0 - exp(-NITRO_LERP * delta))

	var old_x: float = global_position.x
	var target_x: float = RoadConfig.lane_center(target_lane)

	# Smooth approach to the target lane (frame-rate independent).
	global_position.x = lerp(old_x, target_x, 1.0 - exp(-MOVE_SMOOTH * delta))

	# Lateral (sideways) velocity drives the cosmetic bank + nose yaw, handled
	# by CarBank (shared with traffic/enemy cars).
	var lateral_velocity: float = (global_position.x - old_x) / delta

	CarBank.apply(_body, lateral_velocity, BANK_K, YAW_K, delta)
	_detect.rotation.z = _body.rotation.z
	_detect.rotation.y = _body.rotation.y
	_detect.position.z = _body.position.z

	_collect_pickups()

## Collect any pickup that has reached the player's row AND lane.
func _collect_pickups() -> void:
	_collect_group("nitro", GameState.nitro_ready, GameState.store_nitro)
	_collect_group("rocket", GameState.rocket_ready, GameState.store_rocket)

## Collect one pickup from a group if the player is on it and the reserve is empty.
func _collect_group(group: String, has_one: bool, store: Callable) -> void:
	for node in get_tree().get_nodes_in_group(group):
		var pickup := node as Pickup
		if pickup == null or not pickup.is_active():
			continue
		var on_row: bool = absf(pickup.position.z - global_position.z) < 2.0
		var on_lane: bool = absf(global_position.x - RoadConfig.lane_center(pickup.lane)) < 0.7
		if on_row and on_lane:
			if has_one:
				continue
			pickup.deactivate()
			store.call()
			return

## Fire a stored rocket along the car body's forward direction (flies straight
## from the nose; if the car is banking/turning it flies at that angle).
func _try_fire_rocket() -> void:
	if GameState.state != "playing":
		return
	if not GameState.consume_rocket():
		return
	var fwd := -_body.global_transform.basis.z
	var dir := Vector3(fwd.x, 0.0, fwd.z)
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, -1)
	else:
		dir = dir.normalized()
	var rocket: Area3D = RocketScene.instantiate()
	get_tree().current_scene.add_child(rocket)
	rocket.launch(_body.global_position, dir)
