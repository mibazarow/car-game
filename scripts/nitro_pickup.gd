extends Area3D
class_name NitroPickup
## A flat yellow circle that scrolls down the road. The player drives over it
## to activate nitro (~2s), during which the fleeing target car approaches.
## Top-down view: +Y is up, world "forward" (travel direction) is -Z, road
## scrolls +Z. Detected via Area3D (collision_layer = 8).

# Lane center X positions (lanes 0..3, left -> right).
const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
# Where a freshly spawned pickup enters (top of screen, negative Z).
const SPAWN_Z: float = -17.0
# Past this Z the pickup scrolled past the player and is recycled.
const RECYCLE_Z: float = 6.0

## Whether this pickup is currently active (spawned / scrolling / visible).
var active: bool = false

## Place the pickup on a lane and start it scrolling toward the player.
func activate(lane: int) -> void:
	position.x = LANE_X[clampi(lane, 0, 3)]
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

func _physics_process(delta: float) -> void:
	if GameState.state != "playing":
		return
	position.z += GameState.speed * delta
	if position.z > RECYCLE_Z:
		deactivate()
