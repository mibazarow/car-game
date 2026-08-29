extends Node3D
## Procedural endless 4-lane road generator (top-down arcade).
## The road scrolls toward the player (+Z) and segments are recycled to the
## far front (negative Z) when they pass behind the camera.

const SEGMENT_LENGTH := 6.5        # Length of one tile along Z.
const ROAD_HALF_WIDTH := 4.0       # Full road width = 8.0, centered on X=0.
const COVERAGE_MIN := 18.0         # Near/bottom bound (past camera).
const COVERAGE_MAX := -18.0        # Far/front bound (top of screen).

# X positions of the lane divider lines (between the 4 lanes).
const LANE_DIVIDERS := [-2.0, 0.0, 2.0]
# X positions of the two edge lines.
const EDGE_LINES := [-3.5, 3.5]

# Colors (opaque, flat, no textures).
const ASPHALT_COLOR := Color(0.13, 0.13, 0.14)
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

	_asphalt_slab(segment)
	_lane_dividers(segment)
	_edge_lines(segment)
	return segment


func _asphalt_slab(parent: Node3D) -> void:
	var slab := PlaneMesh.new()
	slab.size = Vector2(ROAD_HALF_WIDTH * 2.0, _segment_length)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ASPHALT_COLOR
	mat.roughness = 1.0

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
	var step := GameState.speed * delta
	for child in get_children():
		child.position.z += step
		if child.position.z > COVERAGE_MIN:
			child.position.z -= _total_span
