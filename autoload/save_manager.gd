extends Node
## Persists the best score to disk (user://best.cfg).

const BEST_SAVE_PATH := "user://best.cfg"

func _ready() -> void:
	GameState.best = load_best()

func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_SAVE_PATH) == OK:
		return int(cfg.get_value("score", "best", 0))
	return 0

func save_best(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", value)
	cfg.save(BEST_SAVE_PATH)
