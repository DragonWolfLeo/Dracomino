class_name UI extends Node

signal state_changed(state)

@onready var pauseScreen = $PauseScreen
@onready var dialogueScreen = $DialogueScreen
@onready var debugScreen = $DebugScreen
@onready var dialogueEditWindow:ConfirmationDialog = $DialogueEditWindow
@onready var dialogueEdit:CodeEdit = $DialogueEditWindow/DialogueEdit
@onready var centerLabel:Label = %CenterLabel

enum STATES {
	NORMAL = 1,
	PAUSE = 1 << 1,
	DIALOGUE = 1 << 2,
	DEBUG = 1 << 3,
	DIALOGUE_EDIT = 1 << 4,
	GAMEOVER = 1 << 5,
	NOT_FOCUSED = 1 << 6,

	NOTIFICATION_PAUSE = PAUSE | GAMEOVER | NOT_FOCUSED | DEBUG | DIALOGUE_EDIT
}

@onready var allowedScreens = {
	pauseScreen: STATES.PAUSE | STATES.GAMEOVER | STATES.NOT_FOCUSED,
	dialogueScreen: STATES.DIALOGUE,
	debugScreen: STATES.DEBUG,
	dialogueEditWindow: STATES.DIALOGUE_EDIT,
}

var state:int = 0: set = changeState

func _ready():
	changeState(STATES.NORMAL)
	SignalBus.getSignal("stateflag_set", "gameover").connect(bitsetState.bind(STATES.GAMEOVER))
	SignalBus.getSignal("stateflag_cleared", "gameover").connect(bitclearState.bind(STATES.GAMEOVER))
	SignalBus.getSignal("stateflag_set", "game_focus").connect(bitclearState.bind(STATES.NOT_FOCUSED))
	SignalBus.getSignal("stateflag_cleared", "game_focus").connect(bitsetState.bind(STATES.NOT_FOCUSED))
	
	dialogueEdit.text = ""
	
func bitclearState(_state: int):
	changeState(state &~ _state)

func bitsetState(_state: int):
	changeState((state | _state) &~ STATES.NORMAL) # Unset normal if we're not setting it directly

func bittoggleState(_state: int):
	changeState(state ^ _state)

func changeState(_state: int):
	if _state == 0:
		_state = STATES.NORMAL

	if _state == state: return
	state = _state # Set this here to avoid race conditions
	for screen:Node in allowedScreens.keys():
		if allowedScreens[screen] & state:
			if screen is Window:
				var window:Window = screen as Window
				if not window.visible: window.popup()
			elif screen.has_method("show"): screen.show()
		else:
			if screen.has_method("hide"): screen.hide()
	
	# Control the pausing here
	get_tree().paused = not bool(state & STATES.NORMAL)

	# Set flag for a form of pausing just for notification layer
	if state & STATES.NOTIFICATION_PAUSE:
		FlagManager.setFlag("notification_pause")
	else:
		FlagManager.clearFlag("notification_pause")

	# Set pause screen message
	if state & STATES.NOT_FOCUSED:
		centerLabel.text = "FOCUS LOST"
	elif state & STATES.GAMEOVER:
		centerLabel.text = "GAME OVER"
	else:
		centerLabel.text = "PAUSED"

	state_changed.emit(state)

# === Events ===
func _unhandled_input(event):
	# Regular commands
	if state & STATES.NORMAL:
		if event.is_action_pressed("start"):
			get_viewport().set_input_as_handled()
			bitsetState(STATES.PAUSE)
			return
		elif event.is_action_pressed("help") and FlagManager.isFlagSet("tutorial"):
			get_viewport().set_input_as_handled()
			DialogueManager.loadDialogue(load("res://dialogue/tutorial.script"))
			return
			
	elif state & STATES.GAMEOVER:
		if event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			SignalBus.getSignal("restartGame").emit()
			bitclearState(STATES.PAUSE | STATES.GAMEOVER)
			return
	elif state & STATES.PAUSE:
		if event.is_action_pressed("start"):
			get_viewport().set_input_as_handled()
			bitclearState(STATES.PAUSE)
			return

	# These are all debug commands
	if Config.debugMode:
		if event.is_action_pressed("help"):
			get_viewport().set_input_as_handled()
			if state & STATES.DIALOGUE:
				DialogueManager.closeDialogue()
				if Overlay.fadeActive: Overlay.doFadeOut()
			else:
				DialogueManager.loadDialogue(load("res://dialogue/tutorial.script")) #DEBUG
				bitsetState(STATES.DIALOGUE)
			return
		elif event.is_action_pressed("debug"):
			get_viewport().set_input_as_handled()
			bitsetState(STATES.DEBUG)
			return
		elif event.is_action_pressed("edit"):
			get_viewport().set_input_as_handled()
			bittoggleState(STATES.DIALOGUE_EDIT)
			return

func _on_DialogueInterface_started():
	bitsetState(STATES.DIALOGUE)

func _on_DialogueInterface_finished():
	bitclearState(STATES.DIALOGUE)

func _on_DebugScreen_screen_closed():
	bitclearState(STATES.DEBUG)

func _on_DialogueEditScreen_confirmed() -> void:
	bitclearState(STATES.DIALOGUE_EDIT)
	if dialogueEdit.text.strip_edges().length() == 0:
		return
	var startingState:StringName = ""
	var startingResponse:StringName = ""
	var title = "Dialogue"
	var respath:String = ""
	if DialogueManager.dialogue:
		startingState = DialogueManager.dialogue.startingState
		startingResponse = DialogueManager.dialogue.startingResponse
		title = DialogueManager.dialogue.name
		respath = DialogueManager.dialogue.resourcePath
	DialogueManager.displayCustomDialogue(dialogueEdit.text, startingState, startingResponse)
	if DialogueManager.dialogue:
		DialogueManager.dialogue.name = title
		if respath: DialogueManager.dialogue.resourcePath = respath

var _lastLoadedDialogue:String = ""
func _on_DialogueEdit_visibility_changed() -> void:
	if not is_node_ready(): return
	if dialogueEdit.is_visible_in_tree():
		dialogueEdit.grab_focus()
		if DialogueManager.dialogue != null and (_lastLoadedDialogue == "" or _lastLoadedDialogue != DialogueManager.dialogue.resourcePath):
			dialogueEditWindow.title = DialogueManager.dialogue.resourcePath if DialogueManager.dialogue.resourcePath else (DialogueManager.dialogue.name as String)
			dialogueEdit.clear()
			dialogueEdit.text = DialogueManager.dialogue.text
			_lastLoadedDialogue = DialogueManager.dialogue.resourcePath

func _on_DialogueEditWindow_canceled() -> void:
	bitclearState(STATES.DIALOGUE_EDIT)

func _on_DialogueEdit_hidden() -> void:
	bitclearState(STATES.DIALOGUE_EDIT)

func _on_DialogueEditWindow_window_input(event:InputEvent) -> void:
	if event.is_action_pressed("edit"):
		bitclearState(STATES.DIALOGUE_EDIT)
