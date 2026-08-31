extends CanvasLayer
## Game Over screen: hidden while playing, shown when GameState.state == "game_over".
## Shows the final score and best, and restarts on request.

var _score_value: Label
var _best_value: Label
var _restart_button: Button
var _title: Label

func _ready() -> void:
	_score_value = $Panel/ScoreValue
	_best_value = $Panel/BestValue
	_restart_button = $Panel/RestartButton
	_title = $Panel/Title
	_restart_button.pressed.connect(_restart)

func _process(_delta: float) -> void:
	visible = (GameState.state == "game_over")
	if visible:
		if GameState.victory:
			_title.text = "ПОБЕДА!\nПоздравляем, вы победили!"
		else:
			_title.text = "GAME OVER"
		_score_value.text = "Score: %d" % GameState.score
		_best_value.text = "Best: %d" % GameState.best

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event.is_action_pressed("ui_accept"):
		_restart()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()

func _restart() -> void:
	GameState.reset_run()
	get_tree().reload_current_scene()
