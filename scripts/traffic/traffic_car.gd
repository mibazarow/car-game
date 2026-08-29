extends Area3D
class_name TrafficCar
## Placeholder traffic car (enemy). A purple box that scrolls toward the
## player along the endless 4-lane road. Detected via Area3D for game-over.
## Top-down view: +Y is up, world "forward" (travel) is -Z, road scrolls +Z.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]

# Where a freshly spawned car enters (top of screen, negative Z).
const SPAWN_Z: float = -17.0
# Past this Z the car has passed the player and is recycled.
const RECYCLE_Z: float = 18.0
# Awarded once per car when it passes the player.
const PASS_POINTS := 1
## Minimum world-Z gap to keep behind the car ahead (prevents overlap).
const FOLLOW_DIST: float = 6.0
## X distance (units) beyond which two cars are considered different lanes.
const LANE_TOLERANCE: float = 1.0

## This car's own forward driving speed (units/s), its own `w`.
var forward_speed: float = 0.0
## World-space Z velocity: GameState.speed - forward_speed (always > 0 here).
var speed_z: float = 0.0
## Which lane this car occupies.
var lane: int = 0
## Whether the car is currently in use (spawned / active).
var active: bool = false

## Activate this car on a given lane with a given forward speed.
func activate(new_lane: int, new_forward_speed: float) -> void:
	lane = clamp(new_lane, 0, 3)
	forward_speed = new_forward_speed
	speed_z = GameState.speed - forward_speed
	position.x = LANE_X[lane]
	position.z = SPAWN_Z
	active = true
	set_process(true)
	show()

## Return this car to the pool: stop processing and hide it.
func deactivate() -> void:
	active = false
	set_process(false)
	hide()

signal recycled(car: TrafficCar)

## Whether this car is currently active.
func is_active() -> bool:
	return active

## Nearest active car in the same lane that is ahead (smaller Z). Else null.
func _car_ahead() -> TrafficCar:
	var nearest: TrafficCar = null
	var nearest_z := -3.4028235e38
	for node in get_tree().get_nodes_in_group("traffic"):
		var c := node as TrafficCar
		if c == null or !c.active:
			continue
		if c == self:
			continue
		if c.lane != lane and absf(c.position.x - position.x) > LANE_TOLERANCE:
			continue
		if c.position.z >= position.z:
			continue
		if c.position.z > nearest_z:
			nearest = c
			nearest_z = c.position.z
	return nearest

func _ready() -> void:
	add_to_group("traffic")

func _physics_process(delta: float) -> void:
	speed_z = GameState.speed - forward_speed
	var ahead := _car_ahead()
	if ahead != null:
		var gap := position.z - ahead.position.z
		if gap < FOLLOW_DIST:
			speed_z = minf(speed_z, ahead.speed_z)
	position.z += speed_z * delta
	if position.z > RECYCLE_Z:
		if GameState.state == "playing":
			GameState.add_score(PASS_POINTS)
		deactivate()
		recycled.emit(self)
