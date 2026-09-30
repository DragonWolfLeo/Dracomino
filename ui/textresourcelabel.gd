@tool
extends RichTextLabel

@export var textResources:Dictionary[String, PlainTextResource]:
	set(value):
		if textResources == value: return
		textResources = value
		if Engine.is_editor_hint():
			_renderTextHint()
		else:
			_renderText.call_deferred()

@export var showTitles:bool = true

var scrollbar:VScrollBar

var scrollStrength:float = 0.0
var SCROLL_SPEED:float = 6.0

func _renderText() -> void:
	var textArr:Array[String] = []
	if textResources:
		for title:String in textResources.keys():
			var res:PlainTextResource = textResources[title]
			if res:
				var entry:String = ""
				if showTitles:
					entry = title + "\n\n"
				entry += res.text.replace("\r","")
				textArr.append(entry)
	text = "\n---\n\n".join(textArr)

func _renderTextHint() -> void:
	text = "Will automatically display text resources: [{titles}]".format({
		titles = ", ".join(textResources.keys()) if textResources else ""
	})

func _ready() -> void:
	if Engine.is_editor_hint(): return
	visibility_changed.connect(_on_visibility_changed)
	scrollbar = get_v_scroll_bar()

func _enter_tree() -> void:
	_on_visibility_changed()
	
func _process(_delta):
	if Engine.is_editor_hint(): return
	if scrollbar:
		scrollbar.value += ceil(scrollStrength*SCROLL_SPEED)

func _input(event: InputEvent) -> void:
	if event.is_action("ui_down") or event.is_action("ui_up"):
		scrollStrength = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		accept_event()

func _on_visibility_changed() -> void:
	var isVisible:bool = is_visible_in_tree()
	process_mode = Node.PROCESS_MODE_INHERIT if isVisible else Node.PROCESS_MODE_DISABLED
	set_process_input(isVisible)
	if not isVisible:
		scrollStrength = 0