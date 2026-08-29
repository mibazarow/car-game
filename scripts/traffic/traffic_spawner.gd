extends Node3D
## Spawns and pools placeholder traffic cars on the endless road.
## Top-down view: cars spawn at the top (negative Z) and scroll toward the
## player (+Z), then recycle.

@onready var _scene := preload("res://scenes/TrafficCar.tscn")

## Maximum number of traffic cars kept alive at once.
const MAX_TRAFFIC := 12
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
	if _active_count >= MAX_TRAFFIC:
		return

	var car: Node3D = _get_free_car()
	if car == null:
		car = _scene.instantiate()
		_pool.append(car)
		add_child(car)

	var traffic_car := car as TrafficCar
	traffic_car.recycled.connect(_on_car_recycled)
	traffic_car.activate(randi_range(LANE_MIN, LANE_MAX), randf_range(FORWARD_SPEED_MIN, FORWARD_SPEED_MAX))
	_active_count += 1

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
func _on_car_recycled() -> void:
	_active_count = max(0, _active_count - 1)
