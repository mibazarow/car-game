extends Area3D
class_name NitroPickup
## A flat yellow circle LYING on the road surface. It scrolls with the road
## (moves +Z at GameState.speed), so it comes toward the player from ahead and
## is collected when the player is in its lane as it reaches their row.
## Top-down view: +Y is up, road scrolls +Z.

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
# Where a freshly spawned pickup enters (top of screen, negative Z).
const SPAWN_Z: float = -17.0
# Past this Z the pickup has scrolled past the player and is recycled.
const RECYCLE_Z: float = 6.0

## Whether this pickup is currently active (placed / visible).
var active: bool = false
## Which lane (0..3) this pickup is on.
var lane: int = 0

func _ready() -> void:
	add_to_group("nitro")

## Place the pickup on a lane and start it scrolling toward the player.
func activate(new_lane: int) -> void:
	lane = clampi(new_lane, 0, 3)
	position.x = LANE_X[lane]
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

## Scroll the pickup EXACTLY with the road (same speed/delta as the road
## generator), so it reads as a stone lying on the road surface; recycle once it
## passes the player.
func _process(delta: float) -> void:
	if not active:
		return
	if GameState.state != "playing":
		return
	position.z += GameState.speed * delta
	if position.z > RECYCLE_Z:
		deactivate()
