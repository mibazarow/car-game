extends SceneTree

var _main
var _frames = 0

func _initialize() -> void:
	print("INIT START")
	var root = get_root()
	_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(_main)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames > 60:
		var root = get_root()
		var vp = root.get_viewport()
		print("viewport=", str(vp), " size=", vp.size)
		var tex = vp.get_texture()
		print("texture=", str(tex))
		if tex:
			var img = tex.get_image()
			print("image=", str(img))
			if img:
				img.save_png("/tmp/police_screenshot.png")
				print("SCREENSHOT saved size=", img.get_size())
		quit()
		return true
	return false
