extends Area3D
class_name TrafficCar
## Placeholder traffic car (enemy). A purple box that scrolls toward the
## player along the endless 4-lane road. Detected via Area3D for game-over.
## Top-down view: +Y is up, world "forward" (travel) is -Z, road scrolls +Z.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]

# Where a freshly spawned car enters (top of screen, negative Z).
const SPAWN_Z: float = -25.0
# Past this Z the car has passed the player and is recycled.
const RECYCLE_Z: float = 18.0
## Minimum world-Z gap to keep behind the car ahead (prevents overlap).
const FOLLOW_DIST: float = 6.0
## Extra clearance kept behind the car ahead (units) when held.
const FOLLOW_GAP_MARGIN := 0.3
## X distance (units) beyond which two cars are considered different lanes.
const LANE_TOLERANCE: float = 1.0
# Sentinel for "no car ahead yet" (very negative Z).
const NEG_INF := -3.4028235e38
# Small margin so a held car sits just ABOVE the threat band (not inside it).
const HOLD_MARGIN := 0.01
# Threat band around the player's row [0.5..5.5] (includes approaching cars). With at most 2 cars, and never in adjacent lanes, the player always has a free lane to dodge into — no "checkmate" wall.
const DANGER_Z_MIN: float = 0.5
const DANGER_Z_MAX: float = 5.5
# At most this many cars may be in the danger zone at once. With 2 cars the
# player always has a free lane to dodge to, so a 3-wide "checkmate" wall can
# never form.
const MAX_IN_ZONE := 2

## This car's own forward driving speed (units/s), its own `w`.
var forward_speed: float = 0.0
## World-space Z velocity: GameState.speed - forward_speed (always > 0 here).
var speed_z: float = 0.0
## Which lane this car occupies.
var lane: int = 0
## Whether the car is currently in use (spawned / active).
var active: bool = false

## This car's active collider half-length in Z (set in activate()).
var _half_z: float = 0.0

## Model variant indexes (0..5) that are trucks; trucks drive slower.
const TRUCK_INDEX_START: int = 4
## Model/collider variants in order: Beige, Blue, Yellow, Green, TruckRed, TruckWhite.
var _models: Array[Node3D]
var _colliders: Array[CollisionShape3D]

## Activate this car on a given lane with a given forward speed.
func activate(new_lane: int, new_forward_speed: float) -> void:
	var vi: int = randi_range(0, _models.size() - 1)
	for m in _models:
		m.visible = false
	for c in _colliders:
		c.disabled = true
	_models[vi].visible = true
	_colliders[vi].disabled = false
	_half_z = _colliders[vi].shape.size.z * 0.5
	if vi >= TRUCK_INDEX_START:
		forward_speed = minf(new_forward_speed, randf_range(1.5, 3.5))
	else:
		forward_speed = new_forward_speed
	lane = clamp(new_lane, 0, 3)
	speed_z = GameState.speed - forward_speed
	position.x = LANE_X[lane]
	position.z = SPAWN_Z
	active = true
	set_physics_process(true)
	show()

## Return this car to the pool: stop processing and hide it.
func deactivate() -> void:
	active = false
	set_physics_process(false)
	hide()

signal recycled(car: TrafficCar)

## Whether this car is currently active.
func is_active() -> bool:
	return active

## Nearest active car in the same lane that is ahead (smaller Z). Else null.
func _car_ahead() -> TrafficCar:
	var nearest: TrafficCar = null
	var nearest_z := NEG_INF
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
	_models = [
		get_node("Models/Beige"),
		get_node("Models/Blue"),
		get_node("Models/Yellow"),
		get_node("Models/Green"),
		get_node("Models/TruckRed"),
		get_node("Models/TruckWhite"),
	]
	_colliders = [
		get_node("CollBeige"),
		get_node("CollBlue"),
		get_node("CollYellow"),
		get_node("CollGreen"),
		get_node("CollTruckRed"),
		get_node("CollTruckWhite"),
	]
	add_to_group("traffic")

func _physics_process(delta: float) -> void:
	if GameState.state != "playing":
		return
	if not active:
		return
	# Each car drives at its OWN constant speed (set at spawn). We never
	# re-accelerate it each frame, so cars don't lurch forward. To avoid
	# rear-ending the car ahead, the follower never exceeds the ahead car's
	# speed whenever there is a car directly ahead in the same lane — it never
	# speeds back up, so no jerk.
	var ahead := _car_ahead()
	if ahead != null:
		speed_z = minf(speed_z, ahead.speed_z)

	var next_z: float = position.z + speed_z * delta
	# Physically never pass the car ahead: stay at least a small gap behind its
	# tail even if that car is momentarily held/stopped at the danger zone.
	if ahead != null:
		var max_z: float = ahead.position.z - (_half_z + ahead._half_z) - FOLLOW_GAP_MARGIN
		next_z = minf(next_z, max_z)
	# Anti-checkmate: a car about to enter the player's danger zone holds just
	# above it if the zone is full OR the car would sit next to (adjacent lane)
	# another car already in the zone. This guarantees no 2 cars in adjacent
	# lanes can ever align at the player's row, so the player always has a free
	# lane to dodge into — no "checkmate" even at the edge lanes.
	var will_overfill: bool = _count_in_danger_zone() >= MAX_IN_ZONE
	var will_pair: bool = _adjacent_occupied()
	if position.z < DANGER_Z_MIN and next_z >= DANGER_Z_MIN and (will_overfill or will_pair):
		position.z = DANGER_Z_MIN - HOLD_MARGIN
	else:
		position.z = next_z

	if position.z > RECYCLE_Z:
		if GameState.state == "playing":
			GameState.on_car_passed()
		deactivate()
		recycled.emit(self)

## Number of active traffic cars currently inside the player's danger zone.
func _count_in_danger_zone() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("traffic"):
		var c := node as TrafficCar
		if c == null or not c.active:
			continue
		if c.position.z >= DANGER_Z_MIN and c.position.z <= DANGER_Z_MAX:
			count += 1
	return count

## True if any active car already in the danger zone is in an adjacent lane to
## this car's lane (prevents two side-by-side cars reaching the player at once).
func _adjacent_occupied() -> bool:
	for node in get_tree().get_nodes_in_group("traffic"):
		var c := node as TrafficCar
		if c == null or not c.active or c == self:
			continue
		if c.position.z < DANGER_Z_MIN or c.position.z > DANGER_Z_MAX:
			continue
		if absi(c.lane - lane) == 1:
			return true
	return false
