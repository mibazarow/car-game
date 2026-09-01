class_name CarBank
## Shared cosmetic lane-change physics: roll (rotation.z) banking and nose yaw
## (rotation.y), applied to a car's visual body only (colliders are unaffected).
## Used by the player and the fleeing enemy so the behavior is identical.

const BANK_MAX: float = 0.42      # ~24 degrees of visible roll
const BANK_RISE: float = 10.0     # rad/s ramp toward the bank target while turning
const BANK_FALL: float = 6.0      # rad/s decay back to upright when straight
const YAW_MAX: float = 0.6        # ~34 degrees of visible nose yaw

## Update `body`'s bank (rotation.z) and yaw (rotation.y) from the current
## lateral (X) velocity. `bank_k`/`yaw_k` scale lateral velocity to the target.
static func apply(body: Node3D, lateral_velocity: float, bank_k: float, yaw_k: float, delta: float) -> void:
	var moving: bool = absf(lateral_velocity) > 0.01
	var rise: float = 1.0 - exp(-BANK_RISE * delta)
	var fall: float = 1.0 - exp(-BANK_FALL * delta)

	# Bank (roll): turning into a lane dips the side; decays back to upright.
	var bank_target: float = clampf(lateral_velocity * bank_k, -BANK_MAX, BANK_MAX)
	var bank: float = body.rotation.z
	bank = lerp(bank, bank_target, rise if moving else fall)
	body.rotation.z = -bank

	# Yaw: the nose turns toward the lane-change direction; decays back straight.
	var yaw_target: float = clampf(lateral_velocity * yaw_k, -YAW_MAX, YAW_MAX)
	var yaw: float = body.rotation.y
	yaw = lerp(yaw, -yaw_target, rise if moving else fall)
	body.rotation.y = yaw
