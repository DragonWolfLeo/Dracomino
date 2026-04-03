extends ConsoleWindowContainer

@onready var focusExit = $Bounds/FocusExit
@onready var focusEntrance = $Tabs

func _ready() -> void:
	refresh_hidden()
	# typing_bar.grab_focus()
	get_window().gui_embed_subwindows = true

	if Engine.is_editor_hint(): return

	var right_bar_ws: Array[float] = []
	var register_bar_w: Callable = func(n):
			if n is SliderBox:
				right_bar_ws.push_back(n.get_closed_width())
	for node in console_tab.get_children():
		if node == console_margin: continue
		register_bar_w.call(node)
		Util.for_all_nodes(node, register_bar_w)
	var right_bar_w := 0.0
	for w in right_bar_ws:
		if w > right_bar_w:
			right_bar_w = w
	# console_margin.add_theme_constant_override("margin_right", 8+ceili(right_bar_w / 2))

	# Set up focus entrance and exit
	focusExit.focus_entered.connect(SignalBus.getSignal("give_focus_to_main").emit)

	# Set up grabbing focus on signal
	SignalBus.getSignal("give_focus_to_client").connect(_on_give_focus_to_client)
	focus_entered.connect(_on_give_focus_to_client)

	# Disable processing when window is not focused
	get_window().focus_entered.connect(set.bind("process_mode", PROCESS_MODE_ALWAYS))
	get_window().focus_exited.connect(set.bind("process_mode", PROCESS_MODE_DISABLED))

func _on_give_focus_to_client():
	if not is_visible_in_tree():
		return
	var validFocus:Control = find_next_valid_focus()
	if validFocus: validFocus.grab_focus()

func _on_APButton_pressed() -> void:
	visible = not visible