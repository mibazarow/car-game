extends Pickup
## A flat yellow circle on the road; collected into the nitro reserve.

func _ready() -> void:
	add_to_group("nitro")
