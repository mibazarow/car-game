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

# Small Y offsets to layer the road strips (avoid z-fighting).
const GROUND_OFFSET_Y := -0.02
const LINE_OFFSET_Y := 0.01

var _segment_length := SEGMENT_LENGTH
var _segment_count := 0
var _total_span := 0.0


func _ready() -> void:
	_build_road()


## Create a flat colored plane mesh child.
func _make_plane(parent: Node3D, size: Vector2, color: Color, pos: Vector3, node_name: String) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mat
	mesh.position = pos
	mesh.name = node_name
	parent.add_child(mesh)


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
	_make_plane(parent, Vector2(GROUND_HALF_WIDTH * 2.0, _segment_length), GROUND_COLOR, Vector3(0.0, GROUND_OFFSET_Y, 0.0), "Ground")


## Concrete shoulder strips on each side of the asphalt.
func _shoulders(parent: Node3D) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * (ROAD_HALF_WIDTH + SHOULDER_WIDTH * 0.5)
		_make_plane(parent, Vector2(SHOULDER_WIDTH, _segment_length), SHOULDER_COLOR, Vector3(x, 0.0, 0.0), "Shoulder_" + str(x))


## Thin curb (kerb) strips at the very outer edges.
func _curbs(parent: Node3D) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * (ROAD_HALF_WIDTH + SHOULDER_WIDTH)
		_make_plane(parent, Vector2(CURB_WIDTH, _segment_length), CURB_COLOR, Vector3(x, LINE_OFFSET_Y, 0.0), "Curb_" + str(x))


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
	const LINE_WIDTH := 0.125
	const DASHES_PER_SEGMENT := 3
	const DASH_LEN := 0.9
	var gap := (_segment_length - DASHES_PER_SEGMENT * DASH_LEN) / DASHES_PER_SEGMENT
	var period := DASH_LEN + gap
	for x in LANE_DIVIDERS:
		for i in DASHES_PER_SEGMENT:
			var z := -_segment_length * 0.5 + (i + 0.5) * period
			_make_plane(parent, Vector2(LINE_WIDTH, DASH_LEN), DIVIDER_COLOR, Vector3(x, LINE_OFFSET_Y, z), "Divider_" + str(x) + "_" + str(i))


func _edge_lines(parent: Node3D) -> void:
	for x in EDGE_LINES:
		_make_plane(parent, Vector2(0.25, _segment_length), EDGE_COLOR, Vector3(x, LINE_OFFSET_Y, 0.0), "Edge_" + str(x))


func _process(delta: float) -> void:
	if GameState.state != "playing":
		return
	var step := GameState.speed * delta
	for child in get_children():
		child.position.z += step
		if child.position.z > COVERAGE_MIN:
			child.position.z -= _total_span
