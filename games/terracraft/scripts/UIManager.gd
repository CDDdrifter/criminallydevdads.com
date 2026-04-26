## UIManager -- single source of truth for all UI open/close state.
## All panels must call open()/close() here. Nothing touches InputManager directly.
extends Node

var ui_open: bool = false
var ui_just_closed: bool = false


func open() -> void:
	ui_open = true
	ui_just_closed = false


## One-frame guard so Player won't immediately reopen on the same key press.
func close() -> void:
	ui_open = false
	ui_just_closed = true


## Silently clear the open flag without setting the just_closed guard.
func force_close() -> void:
	ui_open = false
