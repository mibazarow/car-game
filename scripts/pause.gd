extends CanvasLayer
## Pause screen: shown while GameState.state == "paused". Resumes or restarts.

var _resume_button: Button
var _restart_button: Button

func _ready() -> void:
	_resume_button = $Panel/ResumeButton
	_restart_button = $Panel/RestartButton
	_resume_button.pressed.connect(GameState.resume)
	_restart_button.pressed.connect(GameState.reset_run)

func _process(_delta: float) -> void:
	visible = (GameState.state == "paused")

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event.is_action_pressed("ui_accept"):
		GameState.resume()
