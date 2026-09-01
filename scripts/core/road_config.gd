class_name RoadConfig
## Shared geometry constants for the 4-lane road. Every driving entity (player,
## fleeing car, traffic, pickups) reads lane positions from here so the lane
## layout lives in exactly one place (DRY). Lane index 0..3, X grows to the right.

const LANE_X: Array[float] = [-3.0, -1.0, 1.0, 3.0]
const LANE_COUNT: int = 4

## World-space X of the center of a lane (index clamped to [0, LANE_COUNT-1]).
static func lane_center(lane_index: int) -> float:
	return LANE_X[clampi(lane_index, 0, LANE_COUNT - 1)]

## A random valid lane index.
static func random_lane() -> int:
	return randi_range(0, LANE_COUNT - 1)
