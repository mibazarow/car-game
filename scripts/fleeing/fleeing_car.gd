extends Area3D
class_name FleeingCar
## Autonomous fleeing target car pinned near the top of the screen.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z.
## The car never descends and can never be caught; it only wanders lanes and
## dodges oncoming traffic by moving into a free lane. Detected via Area3D.

# Fixed world Z: the car stays pinned near the top of the visible screen.
# NOTE: ortho camera `size` = full diameter, so visible Z is roughly -18..+6;
# -14 sits near the top of the new, larger view. The enemy never moves on nitro
# (the PLAYER surges forward instead).
const Z_POS: float = -14.0
# How far ahead / behind (in Z) we scan for traffic in a given lane.
const DANGER_AHEAD: float = 4.0
const DANGER_BEHIND: float = 1.5
# Frame-rate-independent lateral smoothing.
const MOVE_SMOOTH: float = 6.0
# Lane-change interval bounds (seconds).
const CHANGE_MIN: float = 1.2
const CHANGE_MAX: float = 2.5
# Tolerance (world units) for treating a traffic car as in the same lane.
const LANE_TOLERANCE: float = 1.0

# Cosmetic bank (rotation.z) and yaw (rotation.y) while changing lanes.
const BANK_K := 0.10
const YAW_K := 0.07

var lane: int = 1
var _change_timer: float = 0.0
var _change_interval: float = 2.0
var _body: Node3D

func _ready() -> void:
	add_to_group("fleeing")
	_body = get_node("CarModel")
	position.x = RoadConfig.lane_center(lane)
	position.z = Z_POS

func _physics_process(delta: float) -> void:
	if GameState.state != "playing":
		return
	# The enemy stays pinned near the top; it never approaches the player
	# (nitro makes the PLAYER surge forward instead).
	position.z = Z_POS

	# Countdown to the next autonomous lane change.
	_change_timer -= delta

	# Reactive dodge: if the current lane is blocked right now, immediately
	# move to a safe lane regardless of the timer.
	if _lane_blocked(lane):
		lane = _pick_safe_lane()
		_change_timer = _change_interval
	elif _change_timer <= 0.0:
		# Wander: pick a DIFFERENT safe lane on the autonomous timer so the
		# enemy never sits frozen in one lane when it is not being blocked.
		lane = _pick_different_safe_lane()
		_change_interval = randf_range(CHANGE_MIN, CHANGE_MAX)
		_change_timer = _change_interval

	# Smooth approach to the target lane (frame-rate independent).
	var target_x: float = RoadConfig.lane_center(lane)
	var old_x: float = position.x
	position.x = lerp(position.x, target_x, 1.0 - exp(-MOVE_SMOOTH * delta))
	var lateral_velocity: float = (position.x - old_x) / delta

	CarBank.apply(_body, lateral_velocity, BANK_K, YAW_K, delta)

## Return a lane index (0..3) that is not blocked by traffic. Falls back to the
## current lane if every lane is blocked, or keeps the current lane if it is
## already safe.
func _pick_safe_lane() -> int:
	var safe: Array[int] = []
	for i: int in RoadConfig.LANE_COUNT:
		if not _lane_blocked(i):
			safe.append(i)
	if safe.is_empty():
		return lane
	if not _lane_blocked(lane):
		return lane
	return safe[randi_range(0, safe.size() - 1)]

## Pick a random safe lane DIFFERENT from the current one (autonomous wander).
## Falls back to the current lane if every other lane is blocked.
func _pick_different_safe_lane() -> int:
	var safe: Array[int] = []
	for i: int in RoadConfig.LANE_COUNT:
		if i != lane and not _lane_blocked(i):
			safe.append(i)
	if safe.is_empty():
		return lane
	return safe[randi_range(0, safe.size() - 1)]

## Whether a traffic car currently occupies the given lane within the danger
## window ahead of / behind this car.
func _lane_blocked(lane_idx: int) -> bool:
	for n in get_tree().get_nodes_in_group("traffic"):
		var car: TrafficCar = n as TrafficCar
		if car == null or not car.is_active():
			continue
		if absf(n.position.x - RoadConfig.lane_center(lane_idx)) > LANE_TOLERANCE:
			continue
		var dz: float = n.position.z - position.z
		if dz > -DANGER_AHEAD and dz < DANGER_BEHIND:
			return true
	return false
