extends Control
signal screen_closed()
signal suggestion_accepted()

var history:Array = []
var MAX_HISTORY_ITEMS:int = 20
var MAX_SUGGESTIONS:int = 8
var currentHistoryIndex:int = -1
var _knownCommands:Array = []

@onready var lineEdit:LineEdit = find_child("LineEdit")
@onready var suggestionContainer:Container = find_child("SuggestionContainer")
@onready var hintLabel:Label = find_child("HintLabel")

func _ready():
	setHint()
	clearSuggestions()
	visibility_changed.connect(_on_visibility_changed)
	lineEdit.text_changed.connect(_on_LineEdit_text_changed)
	lineEdit.gui_input.connect(_on_LineEdit_gui_input)
	lineEdit.focus_exited.connect(_on_LineEdit_focus_exited)
	lineEdit.text_submitted.connect(_on_LineEdit_text_submitted)

func parseCommand(commandString:String):
	var params := commandString.split(" ", false, 1)
	if !params.size():
		return
	params[0] = params[0].to_upper()
	params.resize(2) # Fill empty space
	
	var navtagConfig = Dialogue.NAVTAGS.get(params[0])
	if Dialogue.NAVTAGS.has(params[0]):
		addToHistory(commandString)
		# Has to be deferred otherwise it'll compete with signals affecting UI
		DialogueManager.activateNavTagCommand.callv.call_deferred(params)
	elif DracominoCommandManager.COMMANDS.has(params[0]):
		addToHistory(commandString)
		# Ditto
		DracominoCommandManager.activateCommand.callv.call_deferred(params)
	else:
		print(params[0], " is not a valid command.")

func addToHistory(item:String):
	if history.size() == 0 or history.front() != item:
		history.push_front(item)
		if history.size() > MAX_HISTORY_ITEMS:
			history.pop_back()

func clearSuggestions():
	for child in suggestionContainer.get_children():
		child.queue_free()

func setHint(hintText:String = ""):
	if hintText == "":
		hintLabel.hide()
	else:
		hintLabel.show()
		hintLabel.text = hintText

func showHintForCommand(command:String):
	var cmd = Dialogue.NAVTAGS.get(command.to_upper())
	if cmd == null: cmd = DracominoCommandManager.COMMANDS.get(command.to_upper())
	if cmd == null: return
	setHint("{command} {argHint}".format(
		{
			command = command.to_lower(),
			argHint = cmd.argHint if cmd.argHint.length() else "(no options)",
		}
	))

### Events ###
func _on_visibility_changed():
	if is_visible_in_tree():
		get_viewport().set_input_as_handled()
		lineEdit.grab_focus()
		currentHistoryIndex = -1
		_knownCommands = []
		if DialogueManager.dialogue: _knownCommands += Dialogue.NAVTAGS.keys()
		_knownCommands += DracominoCommandManager.COMMANDS.keys()

func _on_LineEdit_gui_input(event:InputEvent):
	var prevHistoryIndex = currentHistoryIndex
	if event.is_action_pressed("ui_text_caret_up"):
		currentHistoryIndex += 1
	elif event.is_action_pressed("ui_text_caret_down"):
		currentHistoryIndex -= 1
	
	currentHistoryIndex = clamp(currentHistoryIndex, -1, history.size() - 1)
	if prevHistoryIndex != currentHistoryIndex:
		get_viewport().set_input_as_handled()
		if currentHistoryIndex == -1:
			lineEdit.text = ""
		else:
			lineEdit.text = history[currentHistoryIndex]
			lineEdit.caret_column = lineEdit.text.length()
	
	if event.is_action_pressed("debug") or event.is_action_pressed("ui_cancel"):
		screen_closed.emit()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_text_submit") and Input.is_key_pressed(KEY_SHIFT):
		suggestion_accepted.emit()
		get_viewport().set_input_as_handled()
		
func _on_LineEdit_text_changed(text:String):
	setHint()
	clearSuggestions()
	if text.length() == 0:
		return
	else:
		var splittext := text.split(" ", false, 1) as Array
		if splittext.size() == 0:
			return
		text = splittext.front()
		if lineEdit.caret_column > text.length():
			showHintForCommand(text)
			return
		var textIsUpper = (text == text.to_upper())
		text = text.to_upper()
		var frontSuggestions := []
		var backSuggestions := []
		_knownCommands.reduce(
			func(acc, cmd:String):
				if cmd.contains(text):
					if cmd.begins_with(text):
						acc.front.append(cmd)
					else:
						acc.back.append(cmd)
				return acc
		, {front = frontSuggestions, back = backSuggestions})
		var suggestions := frontSuggestions + backSuggestions
		if suggestions.size() > MAX_SUGGESTIONS: suggestions.resize(MAX_SUGGESTIONS)
		var btns:Array[Button] = []
		for s:String in suggestions:
			if !textIsUpper:
				s = s.to_lower()
			var btn:Button = Button.new() as Button
			btn.text = s if textIsUpper else s.to_lower()
			suggestionContainer.add_child(btn)
			btns.append(btn)
			btn.pressed.connect(
				func():
					lineEdit.delete_text(0, lineEdit.caret_column)
					lineEdit.insert_text_at_caret(s + " ")
					get_viewport().set_input_as_handled()
					lineEdit.grab_focus()
					clearSuggestions()
			)
		if btns.size():
			setHint("Shift + Enter: Accept")
			suggestion_accepted.connect(btns[0].pressed.emit)

func _on_LineEdit_focus_exited():
	# Only close if not about to press button
	if get_viewport().gui_get_hovered_control() is not Button:
		screen_closed.emit()

func _on_LineEdit_text_submitted(text: String):
	if text.length():
		lineEdit.text = ""
		parseCommand(text)
		clearSuggestions()
		setHint()
	get_viewport().set_input_as_handled()
	screen_closed.emit()
