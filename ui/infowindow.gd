extends Window

@export var autoFocusTarget:Control

func _ready() -> void:
	close_requested.connect(queue_free)
	focus_exited.connect(queue_free)

	if autoFocusTarget:
		var focusTarget:Control = autoFocusTarget
		if autoFocusTarget.focus_mode == Control.FOCUS_NONE:
			focusTarget = autoFocusTarget.find_next_valid_focus()
		if focusTarget:
			focusTarget.grab_focus()

func _enter_tree() -> void:
	grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("back") or event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
		return