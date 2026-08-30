extends SceneTree

var _paths := [
	"res://MODELS/1_police_hero_car_.glb",
	"res://MODELS/2_city_car_beige_.glb",
]
var _i := 0
var _inst

func _process(_delta: float) -> bool:
	if _i >= _paths.size():
		print("\n===== DONE =====")
		quit()
		return true
	if _inst == null:
		var path: String = _paths[_i]
		var res = ResourceLoader.load(path)
		print("\n===== ", path, " =====")
		_inst = res.instantiate()
		root.add_child(_inst)
		print("root type=", _inst.get_class(), " name=", _inst.name)
		print("root visible=", _inst.is_visible(), " scale=", _inst.get_scale(), " process_mode=", _inst.get_process_mode())
		_dump(_inst, 0)
		_inst.free()
		_inst = null
		_i += 1
	return false

func _dump(node: Node, depth: int) -> void:
	var pad := ""
	for i in range(depth):
		pad += "  "
	var t := ""
	if node is MeshInstance3D:
		t = " MESH"
	elif node is CollisionShape3D:
		t = " COLLISION"
	elif node is StaticBody3D:
		t = " STATICBODY"
	elif node is AnimationPlayer:
		t = " ANIM"
	print(pad + node.name + " [" + node.get_class() + "]" + t + " visible=" + str(node.is_visible()) + " scale=" + str(node.get_scale()) + " proc=" + str(node.get_process_mode()))
	for c in node.get_children():
		_dump(c, depth + 1)
