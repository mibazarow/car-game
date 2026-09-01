extends Area3D
class_name TrafficCar
## Placeholder traffic car (enemy). A purple box that scrolls toward the
## player along the endless 4-lane road. Detected via Area3D for game-over.
## Top-down view: +Y is up, world "forward" (travel) is -Z, road scrolls +Z.
## Traffic is one car per lane, so a car never has another car directly ahead
## in its own lane; there is no follow/no-overlap logic. The anti-checkmate
## logic keeps a free lane open for the player at the danger zone.

# Where a freshly spawned car enters (top of screen, negative Z).
const SPAWN_Z: float = -25.0
# Past this Z the car has passed the player and is recycled.
const RECYCLE_Z: float = 18.0
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

## Model variant indexes (0..4) that are trucks; trucks drive slower.
const TRUCK_INDEX_START: int = 3
## Model/collider variants in order: Blue, Yellow, Green, TruckRed, TruckWhite.
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
	if vi >= TRUCK_INDEX_START:
		forward_speed = minf(new_forward_speed, randf_range(1.5, 3.5))
	else:
		forward_speed = new_forward_speed
	lane = clamp(new_lane, 0, 3)
	speed_z = GameState.speed - forward_speed
	position.x = RoadConfig.lane_center(lane)
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

func _ready() -> void:
	_models = [
		get_node("Models/Blue"),
		get_node("Models/Yellow"),
		get_node("Models/Green"),
		get_node("Models/TruckRed"),
		get_node("Models/TruckWhite"),
	]
	_colliders = [
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

	var next_z: float = position.z + speed_z * delta
	# Anti-checkmate: a car about to enter the player's danger zone holds just
	# above it if the zone is already full or the car would sit next to (adjacent
	# lane) a car already in the zone. This prevents two cars in adjacent lanes
	# aligning at the player's row, so the player always has a free lane.
	var will_overfill: bool = _count_in_danger_zone() >= MAX_IN_ZONE
	var will_pair: bool = _adjacent_occupied()
	if position.z < DANGER_Z_MIN and next_z >= DANGER_Z_MIN and (will_overfill or will_pair):
		position.z = DANGER_Z_MIN - HOLD_MARGIN
	else:
		position.z = next_z

	if position.z > RECYCLE_Z:
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
