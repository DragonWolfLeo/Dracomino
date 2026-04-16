extends SubViewportContainer

@onready var ui:UI = %UI
@onready var puzzleMode:Mode = %PuzzleMode
@onready var subviewport:SubViewport = $SubViewport
@onready var effectDurationTicker:Timer = %EffectDurationTicker


var _mode_set_requested_signalholder:SignalBus.SignalHolder

var state:int
var flagHolder:FlagHolder
var currentFocus:Control:
	set(value):
		if currentFocus == value: return
		currentFocus = value
		focus_mode = Control.FOCUS_NONE if currentFocus else FOCUS_CLICK
		if not currentFocus:
			grab_focus()
var activeModes:Array[Control] = []

#==== Virtuals ====
func _init() -> void:
	_mode_set_requested_signalholder = SignalBus.SignalHolder.new()
	SignalBus.registerSignalDistributor(_mode_set_requested_signalholder.triggered, "mode_set_requested")
	
func _ready() -> void:
	flagHolder = FlagHolder.new(FlagHolder.PRIORITY.MAIN)
	flagHolder.tree_entered.connect(FlagManager.HANDLERS.MAIN.setAsFlagHolder.bind(flagHolder))
	add_child(flagHolder)

	subviewport.gui_focus_changed.connect(_on_gui_focus_changed)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_deferred_focus_exited, CONNECT_DEFERRED)
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)

	SignalBus.getSignal("give_focus_to_main").connect(giveFocusToMain)
	for child in subviewport.get_children():
		if child is Mode:
			(child as Mode).mode_enabled.connect(setMode.bind(child as Mode))

	setMode(puzzleMode)

	FlagManager.count("game_focus", "default", 1) # If one thing removes from this count, then be considered unfocused

	effectDurationTicker.timeout.connect(_on_effectDurationTicker_timeout)

	_on_deferred_focus_exited.call_deferred()

func _gui_input(event: InputEvent) -> void:
	if not FlagManager.isFlagSet("game_focus"):
		return

	if event is InputEventMouseButton:
		var mouseEvent:InputEventMouseButton = event as InputEventMouseButton
		if mouseEvent.is_pressed():
			match mouseEvent.button_index:
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
					if FlagManager.isFlagSet("gameover"):
						giveFocusToMain()
						accept_event()
						SignalBus.getSignal("restartGame").emit()
						
func _input(event: InputEvent) -> void:
	if not thisOrChildrenHasFocus():
		return
	# Allow regaining control if setting allows unfocused inputs
	if (
		event.is_action_pressed("start")
		and Config.getSetting("allowUnfocusedInputs", false)
		and not FlagManager.isFlagSet("game_focus")
	):
		FlagManager.count("game_focus", "window_focus_lost", 0)
		if FlagManager.isFlagSet("game_focus"):
			accept_event()
			return

	# Restart the game
	if event.is_action_pressed("restart"):
		SignalBus.getSignal("restartGame").emit()
		accept_event()
		return

	# Give focus to client when pressing tab
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		SignalBus.getSignal("give_focus_to_client").emit()
		accept_event()
		return

#==== Functions ====
func setMode(mode:Control = null):
	if mode == puzzleMode:
		activeModes.clear()
	elif mode and not activeModes.has(mode):
		activeModes.push_front(mode)
	
	mode = null
	for candidate in activeModes:
		if candidate.get_parent() == subviewport:
			mode = candidate
			break
	
	if not mode:
		mode = puzzleMode

	if not subviewport:
		return
	for child in subviewport.get_children():
		if child is Mode:
			child.visible = mode == child
			child.set_process(mode == child)
			child.set_process_input(mode == child)
			child.set_process_unhandled_input(mode == child)
			child.process_mode = PROCESS_MODE_PAUSABLE if mode == child else PROCESS_MODE_DISABLED

func unsetMode(mode:Control):
	activeModes.erase(mode)
	setMode()

func thisOrChildrenHasFocus() -> bool:
	if has_focus():
		return true
	if focusIsExternal():
		return false
	if currentFocus and currentFocus.has_focus():
		return true
	return false

func focusIsExternal() -> bool:
	return get_viewport().gui_get_focus_owner() != null

func giveFocusToMain():
	if currentFocus:
		focus_mode = Control.FOCUS_NONE
		currentFocus.grab_focus()
	else:
		focus_mode = Control.FOCUS_CLICK
		grab_focus()

#==== Events =====
func _on_focus_entered():
	FlagManager.count("game_focus", "main_focus_lost", 0)
	giveFocusToMain()

func _on_deferred_focus_exited():
	if thisOrChildrenHasFocus():
		FlagManager.count("game_focus", "main_focus_lost", 0)
	else:
		FlagManager.count("game_focus", "main_focus_lost", -1)

func _on_window_focus_entered():
	FlagManager.count("game_focus", "window_focus_lost", 0)
	set_process_input(true)
	set_process_unhandled_input(true)

func _on_window_focus_exited():
	FlagManager.count("game_focus", "window_focus_lost", -1)
	if not Config.getSetting("allowUnfocusedInputs", false):
		set_process_input(false)
		set_process_unhandled_input(false)

func _on_gui_focus_changed(node: Control):
	if currentFocus:
		# Probably redundant cleanup
		if currentFocus.focus_exited.is_connected(_on_deferred_currentFocus_focus_exited):
			currentFocus.focus_exited.disconnect(_on_deferred_currentFocus_focus_exited)
	currentFocus = node
	set_process_input(true) # For some reason this stops processing input. Not sure why it does
	FlagManager.count("game_focus", "main_focus_lost", 0)
	node.focus_exited.connect(_on_deferred_currentFocus_focus_exited, CONNECT_ONE_SHOT | CONNECT_DEFERRED)

func _on_deferred_currentFocus_focus_exited():
	var newFocus:Control = subviewport.gui_get_focus_owner()
	if not newFocus:
		# Check if the focus is outside main
		newFocus = get_viewport().gui_get_focus_owner()
		if not newFocus:
			# Clear the focus if the focus is released entirely
			currentFocus = null
		else:
			# Focus is outside main, so set state to not_focused and try to grab click focus
			FlagManager.count("game_focus", "main_focus_lost", -1)
			focus_mode = Control.FOCUS_CLICK

func _on_Board_game_started() -> void:
	setMode(puzzleMode)

func _on_DracominoHandler_started() -> void:
	setMode(puzzleMode)
	grab_focus()

func _on_effectDurationTicker_timeout() -> void:
	effectDurationTicker.start()
	SignalBus.getSignal("effect_duration_down").emit()
