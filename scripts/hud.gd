extends CanvasLayer
## Minimal in-game HUD: shows the current score and best score at the top.

var _score_label: Label
var _nitro_indicator: Panel
var _rocket_indicator: Panel

func _ready() -> void:
	_score_label = $ScoreLabel
	_setup_nitro_indicator()
	_setup_rocket_indicator()
	_refresh()
	GameState.score_changed.connect(_refresh)

func _make_indicator(color: Color, x_offset: float, y_offset: float) -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", style)
	p.size = Vector2(24, 24)
	p.position = Vector2(_score_label.position.x + x_offset, _score_label.position.y + y_offset)
	p.visible = false
	add_child(p)
	return p

func _setup_nitro_indicator() -> void:
	_nitro_indicator = _make_indicator(Color(1, 0.9, 0.1, 1), -36.0, 2.0)

func _setup_rocket_indicator() -> void:
	_rocket_indicator = _make_indicator(Color(0.95, 0.15, 0.1, 1), -66.0, 2.0)

func _process(_delta: float) -> void:
	if _nitro_indicator != null:
		_nitro_indicator.visible = GameState.nitro_ready
	if _rocket_indicator != null:
		_rocket_indicator.visible = GameState.rocket_ready

func _refresh() -> void:
	_score_label.text = "Score: %d    Best: %d" % [GameState.score, GameState.best]
