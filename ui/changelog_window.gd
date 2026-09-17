extends Window

var scrollbar:VScrollBar

var scrollStrength:float = 0.0
var SCROLL_SPEED:float = 6.0

func _ready() -> void:
	var changelogLabel:RichTextLabel = find_child("ChangeLog")
	if changelogLabel is RichTextLabel:
		scrollbar = changelogLabel.get_v_scroll_bar()
		var changelogRes:Resource = load("res://changelog.txt")
		if changelogRes is PlainTextResource:
			changelogLabel.text = (changelogRes as PlainTextResource).text.replace("\r","")
	close_requested.connect(queue_free)
	
func _process(_delta):
	if scrollbar:
		scrollbar.value += ceil(scrollStrength*SCROLL_SPEED)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("back"):
		queue_free()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action("ui_down") or event.is_action("ui_up"):
		scrollStrength = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

func _on_focus_exited() -> void:
	queue_free()
