extends Node
## Sizes the game window to ~75% of the screen height, portrait aspect, centered.

func _ready() -> void:
	size_window()

func size_window() -> void:
	var screen := DisplayServer.screen_get_size()
	if screen == Vector2i.ZERO:
		return
	var screen_pos := DisplayServer.screen_get_position()
	var win_h := int(screen.y * 0.75)
	var win_w := int(win_h * 0.5625)
	var win_size := Vector2i(win_w, win_h)
	var pos := screen_pos + (screen - win_size) / 2
	DisplayServer.window_set_size(win_size)
	DisplayServer.window_set_position(pos)
