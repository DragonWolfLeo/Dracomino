@tool
extends BaseConsole

var SCROLL_SPEED:float = 6.0
var scrollStrength:float = 0.0
var scrollbar:VScrollBar

func _ready() -> void:
	if Engine.is_editor_hint(): return
	super()
	if scroll_cont:
		scrollbar = scroll_cont.get_v_scroll_bar()

func _process(_delta):
	if Engine.is_editor_hint(): return
	if scrollbar:
		scrollbar.value += ceil(scrollStrength*SCROLL_SPEED)

func _gui_input(event):
	if Engine.is_editor_hint(): return
	if event.is_action_pressed("ui_home"):
		scroll_top()
		accept_event()
		return
	if event.is_action_pressed("ui_end"):
		scroll_bottom()
		accept_event()
		return
	if event.is_action_pressed("ui_page_up", true):
		scroll_by_abs(-size.y)
		accept_event()
		return
	if event.is_action_pressed("ui_page_down", true):
		scrollStrength = 0
		scroll_by_abs(size.y)
		accept_event()
		return
	if event.is_action_pressed("ui_text_caret_up", true):
		scrollStrength = 0
		scroll_by_abs(-get_line_height())
		accept_event()
		return
	if event.is_action_pressed("ui_text_caret_down", true):
		scroll_by_abs(get_line_height())
		accept_event()
		return
	if (
		(event.is_action("scrollUp") or event.is_action("scrollDown"))
		and not (Input.is_action_pressed("ui_text_caret_up") or Input.is_action_pressed("ui_text_caret_down"))
	):
		scrollStrength = Input.get_action_strength("scrollDown") - Input.get_action_strength("scrollUp")
		accept_event()
		return

func _on_new_message(_node: Node) -> void:
	if scroll_to_bottom_on_new_message:
		await get_tree().create_timer(0.1).timeout
		scroll_bottom()