extends Node3D
## Procedural endless 4-lane road generator (top-down arcade).
## The road scrolls toward the player (+Z) and segments are recycled to the
## far front (negative Z) when they pass behind the camera.

const SEGMENT_LENGTH := 6.5        # Length of one tile along Z.
const ROAD_HALF_WIDTH := 4.0       # Full road width = 8.0, centered on X=0.
const COVERAGE_MIN := 18.0         # Near/bottom bound (past camera).
const COVERAGE_MAX := -18.0        # Far/front bound (top of screen).
# Ground (grass) extends beyond the shoulders so the road sits on a surface.
const GROUND_HALF_WIDTH := 15.0
# Shoulder strip width on each side of the asphalt (emergency lane / curb base).
const SHOULDER_WIDTH := 1.0
# Curb (kerb) strip width at the very outer edge.
const CURB_WIDTH := 0.25

# X positions of the lane divider lines (between the 4 lanes).
const LANE_DIVIDERS := [-2.0, 0.0, 2.0]
# X positions of the two edge lines.
const EDGE_LINES := [-3.5, 3.5]

# Colors (opaque, flat, no textures).
const GROUND_COLOR := Color(0.17, 0.27, 0.15)   # grass around the road
const ASPHALT_COLOR := Color(0.13, 0.13, 0.14)
const SHOULDER_COLOR := Color(0.42, 0.42, 0.45) # concrete shoulders
const CURB_COLOR := Color(0.62, 0.62, 0.64)     # light curb
const DIVIDER_COLOR := Color(0.9, 0.9, 0.9)
const EDGE_COLOR := Color(0.95, 0.9, 0.2)

var _segment_length := SEGMENT_LENGTH
var _segment_count := 0
var _total_span := 0.0


func _ready() -> void:
	_build_road()


func _build_road() -> void:
	# Enough segments to fully cover [COVERAGE_MAX, COVERAGE_MIN] with no gaps.
	var span := COVERAGE_MIN - COVERAGE_MAX          # 26.0
	_segment_count = int(ceil(span / _segment_length)) + 1  # +1 margin
	_total_span = _segment_count * _segment_length

	for i in _segment_count:
		var segment := _build_segment()
		segment.position.z = COVERAGE_MIN - i * _segment_length
		add_child(segment)


func _build_segment() -> Node3D:
	var segment := Node3D.new()
	segment.name = "Segment"

	_ground(segment)
	_asphalt_slab(segment)
	_shoulders(segment)
	_curbs(segment)
	_lane_dividers(segment)
	_edge_lines(segment)
	return segment


## Wide grass plane below the road, so the road sits on a surface.
func _ground(parent: Node3D) -> void:
	var ground := PlaneMesh.new()
	ground.size = Vector2(GROUND_HALF_WIDTH * 2.0, _segment_length)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 1.0

	var mesh := MeshInstance3D.new()
	mesh.mesh = ground
	mesh.material_override = mat
	mesh.position = Vector3(0.0, -0.02, 0.0)
	mesh.name = "Ground"
	parent.add_child(mesh)


## Concrete shoulder strips on each side of the asphalt.
func _shoulders(parent: Node3D) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * (ROAD_HALF_WIDTH + SHOULDER_WIDTH * 0.5)
		var shoulder := PlaneMesh.new()
		shoulder.size = Vector2(SHOULDER_WIDTH, _segment_length)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = SHOULDER_COLOR
		mat.roughness = 1.0

		var mesh := MeshInstance3D.new()
		mesh.mesh = shoulder
		mesh.material_override = mat
		mesh.position = Vector3(x, 0.0, 0.0)
		mesh.name = "Shoulder_" + str(x)
		parent.add_child(mesh)


## Thin curb (kerb) strips at the very outer edges.
func _curbs(parent: Node3D) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * (ROAD_HALF_WIDTH + SHOULDER_WIDTH)
		var curb := PlaneMesh.new()
		curb.size = Vector2(CURB_WIDTH, _segment_length)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = CURB_COLOR
		mat.roughness = 1.0

		var mesh := MeshInstance3D.new()
		mesh.mesh = curb
		mesh.material_override = mat
		mesh.position = Vector3(x, 0.01, 0.0)
		mesh.name = "Curb_" + str(x)
		parent.add_child(mesh)


func _asphalt_slab(parent: Node3D) -> void:
	const TILES_ACROSS := 6.0
	var tex := load("res://MODELS/asfalt_2.png")

	var slab := PlaneMesh.new()
	slab.size = Vector2(ROAD_HALF_WIDTH * 2.0, _segment_length)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 1.0

	var tile_world := (ROAD_HALF_WIDTH * 2.0) / TILES_ACROSS
	var tiles_along := _segment_length / tile_world
	mat.uv1_scale = Vector3(TILES_ACROSS, tiles_along, 1.0)

	var mesh := MeshInstance3D.new()
	mesh.mesh = slab
	mesh.material_override = mat
	mesh.name = "Asphalt"
	parent.add_child(mesh)


func _lane_dividers(parent: Node3D) -> void:
	for x in LANE_DIVIDERS:
		var line := PlaneMesh.new()
		line.size = Vector2(0.25, _segment_length)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = DIVIDER_COLOR
		mat.roughness = 1.0

		var mesh := MeshInstance3D.new()
		mesh.mesh = line
		mesh.material_override = mat
		mesh.position = Vector3(x, 0.01, 0.0)
		mesh.name = "Divider_" + str(x)
		parent.add_child(mesh)


func _edge_lines(parent: Node3D) -> void:
	for x in EDGE_LINES:
		var line := PlaneMesh.new()
		line.size = Vector2(0.25, _segment_length)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = EDGE_COLOR
		mat.roughness = 1.0

		var mesh := MeshInstance3D.new()
		mesh.mesh = line
		mesh.material_override = mat
		mesh.position = Vector3(x, 0.01, 0.0)
		mesh.name = "Edge_" + str(x)
		parent.add_child(mesh)


func _process(delta: float) -> void:
	if GameState.state != "playing":
		return
	var step := GameState.speed * delta
	for child in get_children():
		child.position.z += step
		if child.position.z > COVERAGE_MIN:
			child.position.z -= _total_span
