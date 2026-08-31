extends Node
## Central audio: looping engine background + one-shot nitro SFX.

var _engine: AudioStreamPlayer
var _nitro: AudioStreamPlayer

func _ready() -> void:
	_setup_audio()

func _setup_audio() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.stream = load("res://MODELS/engine.wav")
	_engine.volume_db = linear_to_db(0.25)
	_engine.finished.connect(func() -> void: _engine.play())
	add_child(_engine)

	_nitro = AudioStreamPlayer.new()
	_nitro.stream = load("res://MODELS/nitro.wav")
	_nitro.volume_db = linear_to_db(0.25)
	add_child(_nitro)

func _process(_delta: float) -> void:
	# Engine hums while the game is active; silent in menu / game over.
	var want: bool = GameState.state == "playing" or GameState.state == "paused"
	if want and not _engine.is_playing():
		_engine.play()
	elif not want and _engine.is_playing():
		_engine.stop()

## Play the one-shot nitro pickup sound.
func play_nitro() -> void:
	if _nitro != null:
		_nitro.stop()
		_nitro.play()
