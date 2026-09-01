class_name Pickup
extends Area3D
## Shared pickup logic: lies flat on the road, scrolls with it (+Z), and is
## activated/deactivated by a spawner. Subclasses add themselves to a group.

# Where a freshly spawned pickup enters (top of screen, negative Z).
const SPAWN_Z: float = -25.0
# Past this Z the pickup has scrolled past the player and is recycled.
const RECYCLE_Z: float = 6.0

## Whether this pickup is currently active (placed / visible).
var active: bool = false
## Which lane (0..3) this pickup is on.
var lane: int = 0

## Place the pickup on a lane and start it scrolling toward the player.
func activate(new_lane: int) -> void:
	lane = clampi(new_lane, 0, 3)
	position.x = RoadConfig.lane_center(lane)
	position.z = SPAWN_Z
	active = true
	set_process(true)
	show()

## Return the pickup to the pool: stop processing and hide it.
func deactivate() -> void:
	active = false
	set_process(false)
	hide()

## Whether this pickup is currently active.
func is_active() -> bool:
	return active

## Scroll the pickup EXACTLY with the road; recycle once it passes the player.
func _process(delta: float) -> void:
	if not active or GameState.state != "playing":
		return
	position.z += GameState.speed * delta
	if position.z > RECYCLE_Z:
		deactivate()
