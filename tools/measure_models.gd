extends SceneTree

var _models := [
	"res://MODELS/1_police_hero_car_.glb",
	"res://MODELS/2_city_car_beige_.glb",
	"res://MODELS/3_city_car_blue_.glb",
	"res://MODELS/4_city_car_yellow_.glb",
	"res://MODELS/5_city_car_green_.glb",
	"res://MODELS/6_semi_truck_red_.glb",
	"res://MODELS/7_semi_truck_white_.glb",
]
var _i := 0
var _inst

func _process(_delta: float) -> bool:
	print("PROCESS _i=", _i, " models=", _models.size())
	if _i < _models.size():
		var path: String = _models[_i]
		if _inst != null:
			_inst.free()
		var ps = load(path)
		print("LOADED ", path, " ps=", ps)
		_inst = ps.instantiate()
		print("INSTANTIATED ", path, " inst=", _inst)
		root.add_child(_inst)
		_i += 1
		return false
	if _inst != null:
		_inst.free()
		return true
	return false
