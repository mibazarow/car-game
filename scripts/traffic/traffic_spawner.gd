extends Node3D
## Spawns and pools placeholder traffic cars on the endless road.
## Top-down view: cars spawn at the top (negative Z) and scroll toward the
## player (+Z), then recycle.

@onready var _scene := preload("res://scenes/TrafficCar.tscn")

## Maximum number of traffic cars kept alive at once (2 per lane x 4 lanes).
const MAX_TRAFFIC := 8
## Maximum cars in the same lane at once.
const MAX_PER_LANE := 2
## A new car may spawn in a lane only if an existing car there is at least this
## far ahead of the spawn point (room for the follower; it inherits its speed).
const SPAWN_AHEAD_GAP: float = 16.0
## Time between spawns.
const SPAWN_INTERVAL: float = 0.75
## Lane range (0..3).
const LANE_MIN := 0
const LANE_MAX := 3
## Per-car forward speed range (units/s).
const FORWARD_SPEED_MIN: float = 3.0
const FORWARD_SPEED_MAX: float = 7.0


var _timer: Timer
## Pool of traffic instances (active or idle).
var _pool: Array = []
## Number of currently active cars.
var _active_count: int = 0

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = SPAWN_INTERVAL
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

## Spawn one traffic car from the pool (or create a new instance).
func _spawn() -> void:
	if GameState.state != "playing":
		return
	if _active_count >= MAX_TRAFFIC:
		return

	var car: Node3D = _get_free_car()
	if car == null:
		car = _scene.instantiate()
		_pool.append(car)
		add_child(car)
		# Connect the recycle signal once per instance (avoid duplicates on reuse).
		(car as TrafficCar).recycled.connect(_on_car_recycled)

	# Pick the first of up to 4 random lanes that is clear at the spawn point.
	var chosen_lane := -1
	for _i in 4:
		var cand := randi_range(LANE_MIN, LANE_MAX)
		if _lane_clear_at_spawn(cand):
			chosen_lane = cand
			break
	if chosen_lane < 0:
		return

	var traffic_car := car as TrafficCar
	# If the chosen lane already has a car, the new one inherits its speed so the
	# follower never catches up to the leader (no overlap, no pile-up).
	var leader_speed := -1.0
	for node in get_tree().get_nodes_in_group("traffic"):
		var c := node as TrafficCar
		if c != null and c.active and c.lane == chosen_lane:
			leader_speed = c.speed_z
			break
	traffic_car.activate(chosen_lane, randf_range(FORWARD_SPEED_MIN, FORWARD_SPEED_MAX), leader_speed)
	_active_count += 1

## Allow spawning into a lane if it has fewer than MAX_PER_LANE cars AND any car
## already there has advanced at least SPAWN_AHEAD_GAP ahead of the spawn point
## (so there's room, and the follower inherits the leader's speed / no overlap).
func _lane_clear_at_spawn(lane_idx: int) -> bool:
	var count := 0
	var far_enough := true
	for node in get_tree().get_nodes_in_group("traffic"):
		var c := node as TrafficCar
		if c == null or not c.active or c.lane != lane_idx:
			continue
		count += 1
		if c.position.z > TrafficCar.SPAWN_Z + SPAWN_AHEAD_GAP:
			far_enough = false
	return count < MAX_PER_LANE and far_enough

## Grab an inactive car from the pool, or return null if none is free.
func _get_free_car() -> Node3D:
	for candidate in _pool:
		var c := candidate as TrafficCar
		if c != null and !c.is_active():
			return candidate
	return null

func _on_timeout() -> void:
	_spawn()

## Called by TrafficCar when it recedes past the player.
func _on_car_recycled(_car: TrafficCar) -> void:
	_active_count = max(0, _active_count - 1)
