extends Pickup
## A flat red circle on the road; collected into the rocket reserve.

func _ready() -> void:
	add_to_group("rocket")
