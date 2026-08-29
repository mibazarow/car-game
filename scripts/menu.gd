extends CanvasLayer
## Menu screen: shown while GameState.state == "menu". Starts the run on
## Play button press or ui_accept.

var _best_value: Label
var _play_button: Button

func _ready() -> void:
	_best_value = $Panel/BestValue
	_play_button = $Panel/PlayButton
	_play_button.pressed.connect(_start)

func _process(_delta: float) -> void:
	visible = (GameState.state == "menu")
	if visible:
		_best_value.text = "Best: %d" % GameState.best

func _unhandled_input(event: InputEvent) -> void:
	if !visible:
		return
	if event.is_action_pressed("ui_accept"):
		_start()

func _start() -> void:
	GameState.start_game()
