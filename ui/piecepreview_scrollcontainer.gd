extends ScrollContainer

func _ready() -> void:
	# Only enable mouse inputs if scroll bar is visible
	var scrollbar:VScrollBar = get_v_scroll_bar()
	scrollbar.visibility_changed.connect(_on_scrollbar_visibility_changed.bind(scrollbar))
	processMouseInputs(scrollbar.visible)

func processMouseInputs(doProcess:bool = true) -> void: ## Allow scrollcontainer to handle mouse inputs
	mouse_filter = MOUSE_FILTER_PASS if doProcess else MOUSE_FILTER_IGNORE

func _on_scrollbar_visibility_changed(scrollbar:ScrollBar) -> void:
	processMouseInputs(scrollbar.is_visible_in_tree())