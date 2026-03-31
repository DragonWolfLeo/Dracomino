extends SubViewportContainer

signal mode_set_requested(modeName:StringName)

@onready var centerLabel:Label = %CenterLabel
@onready var notificationLabel:Label = %NotificationLabel
@onready var puzzleMode:Mode = %PuzzleMode

var _timer:SceneTreeTimer
var _queuedNotifications:Array[Dictionary]

enum STATE {
	NORMAL,
	PAUSED,
	GAMEOVER,
}
var state:int: set = _set_state
var DRACOMINO_NOTIFICATION_TIME:float = 5.0
var DRACOMINO_NOTIFICATION_TIME_SHORT:float = 1.0

#==== Virtuals ====
func _init() -> void:
	SignalBus.registerSignalDistributor(mode_set_requested, "mode_set_requested")
	
func _ready() -> void:
	notificationLabel.text = ""
	notificationLabel.hide()
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)
	state = STATE.PAUSED

	SignalBus.getSignal("give_focus_to_main").connect(grab_focus)
	for child in $SubViewport.get_children():
		if child is Mode:
			(child as Mode).mode_enabled.connect(setMode.bind(child as Mode))

	setMode()

#==== Functions ====
func applyState() -> void:
	if centerLabel == null: return
	match state:
		STATE.NORMAL:
			get_tree().paused = false
			centerLabel.hide()
		STATE.PAUSED:
			get_tree().paused = true
			centerLabel.text = "PAUSED"
			centerLabel.show()
		STATE.GAMEOVER:
			get_tree().paused = true
			centerLabel.text = "GAME OVER"
			centerLabel.show()

func showNotification(notif:String, color:Color) -> void:
	if _timer and _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
	if notificationLabel:
		notificationLabel.show()
		notificationLabel.text = notif
		notificationLabel.label_settings.font_color = color
		_timer = get_tree().create_timer(DRACOMINO_NOTIFICATION_TIME_SHORT if _queuedNotifications.size() else DRACOMINO_NOTIFICATION_TIME, false)
		_timer.timeout.connect(_on_timer_timeout)

func setMode(mode:Control = null):
	if not mode:
		mode = puzzleMode
	if mode.get_parent() != $SubViewport:
		printerr("Mode must be a parent of Main/SubViewport")
		mode = puzzleMode
	
	for child in $SubViewport.get_children():
		if child is Mode:
			child.visible = mode == child
			child.set_process(mode == child)
			child.set_process_input(mode == child)
			child.set_process_unhandled_input(mode == child)
			child.process_mode = PROCESS_MODE_PAUSABLE if mode == child else PROCESS_MODE_DISABLED

#==== Events =====
func _on_focus_entered():
	if state != STATE.GAMEOVER:
		state = STATE.NORMAL

func _on_focus_exited():
	await get_tree().process_frame
	if has_focus(): return # Takes focus back when clicking on container
	if state != STATE.GAMEOVER:
		state = STATE.PAUSED

func _on_window_focus_entered():
	set_process_input(true)
	set_process_unhandled_input(true)

func _on_window_focus_exited():
	if not Config.getSetting("allowUnfocusedInputs", false):
		set_process_input(false)
		set_process_unhandled_input(false)
	if state != STATE.GAMEOVER:
		state = STATE.PAUSED

func _on_Board_game_over_earned() -> void:
	state = STATE.GAMEOVER

func _on_Board_game_started() -> void:
	setMode()
	state = STATE.NORMAL

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouseEvent:InputEventMouseButton = event as InputEventMouseButton
		if mouseEvent.is_pressed():
			match mouseEvent.button_index:
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
					var localEvent = make_input_local(event)
					if get_rect().has_point(localEvent.position):
						_on_focus_exited()
					else:
						grab_focus()
						_on_focus_entered()
						if state == STATE.GAMEOVER:
							accept_event()
							SignalBus.getSignal("restartGame").emit()
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		SignalBus.getSignal("give_focus_to_client").emit()

	if event.is_action_pressed("restart"):
		SignalBus.getSignal("restartGame").emit()
		accept_event()
		return
	match state:
		STATE.NORMAL:
			if event.is_action_pressed("start"):
				accept_event()
				state = STATE.PAUSED
		STATE.PAUSED:
			if event.is_action_pressed("start"):
				accept_event()
				state = STATE.NORMAL
		STATE.GAMEOVER:
			if event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
				accept_event()
				SignalBus.getSignal("restartGame").emit()

func _set_state(value:int) -> void:
	if state == value:
		return
	state = value
	applyState()

func _on_DracominoHandler_notification_signal(notif:String, color:Color, force:bool = false) -> void:
	if _timer and not force:
		_timer.time_left = min(DRACOMINO_NOTIFICATION_TIME_SHORT, _timer.time_left)
		_queuedNotifications.append({
			notif = notif,
			color = color,
		})
	else:
		showNotification(notif, color)
		
func _on_timer_timeout():
	if _queuedNotifications.size():
		var qn:Dictionary = _queuedNotifications.pop_front()
		showNotification(qn.notif, qn.color)
	else:
		notificationLabel.hide()
		_timer = null

func _on_DracominoHandler_started() -> void:
	setMode()
	grab_focus()


func _on_Board_effect_activated(item: DracominoHandler.StateItem) -> void:
	var formatValues:Dictionary = {
		itemName = item.data.prettyName if item.data else &"Unknown Effect",
		senderName = item.senderName,
		gameName = item.gameName,
	}
	if item.isLocal:
		showNotification("Triggered your own {itemName}!".format(formatValues), CONSTANTS.COLOR.TRAP)
	else:
		showNotification("Triggered {itemName} from {senderName}'s {gameName}!".format(formatValues), CONSTANTS.COLOR.TRAP)
