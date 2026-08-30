extends SceneTree

func _initialize() -> void:
	var root: Node = self.root
	var paths := [
		"res://MODELS/6_semi_truck_red_.glb",
		"res://MODELS/7_semi_truck_white_.glb",
	]
	for p in paths:
		_dump(p, root)
	quit()

func _dump(p: String, root: Node) -> void:
	print("\n========== ", p, " ==========")
	var res := ResourceLoader.load(p)
	if res == null:
		print("LOAD FAILED")
		return
	var scene := res as PackedScene
	if scene == null:
		print("NOT A PACKED SCENE")
		return
	var inst := scene.instantiate()
	root.add_child(inst)
	await process_frame
	print("  inst root class: ", inst.get_class(), " name: ", inst.name, " children: ", inst.get_child_count(), " is_red=", p.contains("red"))
	_walk(inst, p.contains("red"))
	inst.free()

func _walk(node: Node, is_red: bool) -> void:
	if node is MeshInstance3D:
		_inspect_mesh(node, is_red)
	for c in node.get_children():
		_walk(c, is_red)

func _inspect_mesh(mi: MeshInstance3D, is_red: bool) -> void:
	var mesh := mi.get_mesh()
	if mesh == null:
		print("  (no mesh)")
		return
	var n := mesh.get_surface_count()
	print("  MeshInstance3D: ", mi.name, "  surfaces: ", n)
	for s in range(n):
		var mat := mesh.surface_get_material(s)
		print("  [surface ", s, "]")
		if mat == null:
			print("    material: null")
		else:
			print("    material class: ", mat.get_class())
			if mat is BaseMaterial3D:
				var info := mat.get_property_list()
				for prop in info:
					var pn: String = prop["name"]
					if pn == "albedo_color" or pn == "albedo_texture" or pn == "transparency" or pn == "shading_mode" or pn == "cull_mode" or pn == "roughness" or pn == "metallic" or pn == "vertex_color_use_as_albedo" or pn == "emission" or pn == "emission_texture" or pn == "emission_enabled":
						print("    PROP ", pn, " = ", str(mat.get(pn)))
			if mat is StandardMaterial3D:
				var bm := mat as BaseMaterial3D
				print("    albedo_color: ", bm.albedo_color)
				print("    albedo_texture: ", str(bm.albedo_texture))
				if bm.albedo_texture != null:
					var img := bm.albedo_texture.get_image()
					if img != null:
						print("      img size: ", img.get_width(), "x", img.get_height())
						var c := img.get_pixel(0, 0)
						print("      pixel[0,0]: ", c)
						c = img.get_pixel(img.get_width()-1, img.get_height()-1)
						print("      pixel[last]: ", c)
						# average color over a sample
						var sum_r:=0.0; var sum_g:=0.0; var sum_b:=0.0; var cnt:=0
						var step := 64
						var tw := img.get_width(); var th := img.get_height()
						var yy := 0
						while yy < th:
							var xx := 0
							while xx < tw:
								var px := img.get_pixel(xx, yy)
								sum_r += px.r; sum_g += px.g; sum_b += px.b; cnt += 1
								xx += step
							yy += step
						print("      avg color (r,g,b) over ", cnt, " px: ", sum_r/cnt, ", ", sum_g/cnt, ", ", sum_b/cnt)
						print("      DEBUG about to save, is_red=", is_red, " tw=", tw, " th=", th)
						# save raw RGBA to file for external comparison
						var rgba := PackedByteArray()
						var _yy := 0
						while _yy < th:
							var _xx := 0
							while _xx < tw:
								var _p := img.get_pixel(_xx, _yy)
								rgba.append(int(_p.r*255))
								rgba.append(int(_p.g*255))
								rgba.append(int(_p.b*255))
								rgba.append(255)
								_xx += step
							_yy += step
						# write with a path derived from truck name
						var fname := OS.get_user_data_dir() + "/avg_" + ("red" if is_red else "white") + ".raw"
						var f := FileAccess.open(fname, FileAccess.WRITE)
						if f != null:
							var w: int = f.write_data(rgba)
							f.close()
							print("      wrote ", fname, " bytes_written=", w, " expected=", rgba.size())
						else:
							print("      FILE OPEN FAILED for ", fname, " err=", FileAccess.get_open_error())
					else:
						print("      img is NULL (failed to load!)")
				print("    transparency: ", bm.transparency)
				print("    shading_mode: ", bm.shading_mode)
				print("    cull_mode: ", bm.cull_mode)
				print("    roughness: ", bm.roughness)
				print("    metallic: ", bm.metallic)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				print("    vertex_color_use_as_albedo: ", sm.vertex_color_use_as_albedo)
		var arr := mesh.surface_get_arrays(s)
		if arr.size() > Mesh.ARRAY_COLOR and arr[Mesh.ARRAY_COLOR] != null:
			var colors: Array = arr[Mesh.ARRAY_COLOR]
			print("    HAS_VERTEX_COLORS count=", colors.size())
			for i in range(min(5, colors.size())):
				print("      color[", i, "]: ", colors[i])
		else:
			print("    NO_VERTEX_COLORS")
