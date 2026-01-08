extends Control

var centerLabel:Label
var levelContainer:Control
var notificationLabel:Label
var linesLabel:Label
var piecesLabel:Label
var _timer:SceneTreeTimer
var _queuedNotifications:Array[Dictionary]
var level:Board
var _goal:int=0
var _line:int=0
var _piecesStoredInPreview:int=0
var _piecesLeft:int=0

enum STATE {
	NORMAL,
	PAUSED,
	GAMEOVER,
}
var state:int: set = _set_state
var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")

#==== Virtuals ====
func _ready() -> void:
	levelContainer = find_child("LevelContainer")
	centerLabel = find_child("CenterLabel")
	notificationLabel = find_child("NotificationLabel")
	linesLabel = find_child("LinesLabel")
	piecesLabel = find_child("PiecesLabel")
	level = find_child("Board")
	notificationLabel.text = ""
	notificationLabel.hide()
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_window_focus_entered)
	get_window().focus_exited.connect(_on_window_focus_exited)
	state = STATE.PAUSED

	_on_SubViewportContainer_resized.call_deferred()

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
		_timer = get_tree().create_timer(5, false)
		_timer.timeout.connect(_on_timer_timeout)

func updateLineClearedLabel():
	if linesLabel:
		linesLabel.text = "Lines: {num} / {goal}".format({num=_line,goal=_goal})

#==== Events =====
func _on_focus_entered():
	if state != STATE.GAMEOVER:
		state = STATE.NORMAL

func _on_focus_exited():
	if state != STATE.GAMEOVER:
		state = STATE.PAUSED

func _on_window_focus_entered():
	set_process_input(true)

func _on_window_focus_exited():
	set_process_input(false)
	_on_focus_exited()

func _on_Board_game_over_earned() -> void:
	state = STATE.GAMEOVER

func _on_Board_game_started() -> void:
	state = STATE.NORMAL

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouseEvent:InputEventMouseButton = event as InputEventMouseButton
		if mouseEvent.is_pressed():
			match mouseEvent.button_index:
				MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
					var localEvent = levelContainer.make_input_local(event)
					if !levelContainer.get_rect().has_point(localEvent.position):
						_on_focus_exited()
					else:
						grab_focus()
						_on_focus_entered()
						if state == STATE.GAMEOVER:
							accept_event()
							SignalBus.getSignal("restartGame").emit()

func _unhandled_input(event: InputEvent) -> void:
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

func _on_Btn_Quit_pressed() -> void:
	get_tree().quit()

func _on_DracominoState_notification_signal(notif:String, color:Color, force:bool = false) -> void:
	if _timer and not force:
		_timer.time_left = min(1.0, _timer.time_left)
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

func _on_Board_lines_cleared_updated(num: int = _line) -> void:
	_line = num
	updateLineClearedLabel()

func _on_DracominoState_pieces_left_updated(total:int = _piecesLeft) -> void:
	_piecesLeft = total
	if piecesLabel:
		piecesLabel.text = "Pieces Left: {total}".format({total=_piecesLeft+_piecesStoredInPreview})

func _on_DracominoState_goal_updated(goalnum:int) -> void:
	_goal = goalnum
	updateLineClearedLabel()

func _on_SubViewportContainer_resized() -> void:
	await get_tree().process_frame
	if level:
		var rect = level.get_viewport_rect()
		var levelNativeHeight = (Board.BOUNDS.size.y + 6) * 16 # TODO: Move this magic number (tile size)
		var scaleMultiplier:int = max(1, floor(rect.size.y / levelNativeHeight))
		level.scale = Vector2(scaleMultiplier, scaleMultiplier)

func _on_PreviewStorage_num_stored_changed(num:int) -> void:
	_piecesStoredInPreview = num
	_on_DracominoState_pieces_left_updated()

func _on_BtnChangelog_pressed() -> void:
	var _changelogWindow:Window = CHANGELOG_WINDOW_SCENE.instantiate() as Window
	_changelogWindow.popup_exclusive_centered(self)

func _on_DracominoHandler_started() -> void:
	grab_focus()
