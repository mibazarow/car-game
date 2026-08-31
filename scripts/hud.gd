extends CanvasLayer
## Minimal in-game HUD: shows the current score and best score at the top.

var _score_label: Label
var _nitro_indicator: Panel

func _ready() -> void:
	_score_label = $ScoreLabel
	_setup_nitro_indicator()
	_refresh()
	GameState.score_changed.connect(_refresh)

func _setup_nitro_indicator() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.9, 0.1, 1)
	style.set_corner_radius_all(12)
	_nitro_indicator = Panel.new()
	_nitro_indicator.add_theme_stylebox_override("panel", style)
	_nitro_indicator.size = Vector2(24, 24)
	_nitro_indicator.position = Vector2(_score_label.position.x - 36, _score_label.position.y + 2)
	_nitro_indicator.visible = false
	add_child(_nitro_indicator)

func _process(_delta: float) -> void:
	if _nitro_indicator != null:
		_nitro_indicator.visible = GameState.nitro_ready

func _refresh() -> void:
	_score_label.text = "Score: %d    Best: %d" % [GameState.score, GameState.best]
