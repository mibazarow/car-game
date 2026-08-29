extends CanvasLayer
## Minimal in-game HUD: shows the current score and best score at the top.

var _score_label: Label

func _ready() -> void:
	_score_label = $ScoreLabel
	_refresh()
	GameState.score_changed.connect(_refresh)

func _refresh() -> void:
	_score_label.text = "Score: %d    Best: %d" % [GameState.score, GameState.best]
