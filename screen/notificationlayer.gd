extends CanvasLayer

@onready var notificationLabel:Label = %NotificationLabel
@onready var timer:Timer = $Timer

var _queuedNotifications:Array[Dictionary]

var DRACOMINO_NOTIFICATION_TIME:float = 5.0
var DRACOMINO_NOTIFICATION_TIME_SHORT:float = 1.0

# === Virtuals ===
func _ready():
	notificationLabel.text = ""
	notificationLabel.hide()
	SignalBus.getSignal("stateflag_set", "notification_pause").connect(timer.set.bind("paused", true))
	SignalBus.getSignal("stateflag_cleared", "notification_pause").connect(timer.set.bind("paused", false))

# === Functions ===
func showNotification(notif:String, color:Color) -> void:
	cancelTimer()
	if notificationLabel:
		notificationLabel.show()
		notificationLabel.text = notif
		notificationLabel.label_settings.font_color = color
		timer.start(DRACOMINO_NOTIFICATION_TIME_SHORT if _queuedNotifications.size() else DRACOMINO_NOTIFICATION_TIME)
		timer.timeout.connect(_on_timer_timeout, CONNECT_ONE_SHOT)

func cancelTimer() -> void:
	if timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.disconnect(_on_timer_timeout)
		timer.stop()

# === Events ===
func _on_DracominoHandler_notification_signal(notif:String, color:Color, force:bool = false) -> void:
	if not timer.is_stopped() and not force:
		timer.start(min(DRACOMINO_NOTIFICATION_TIME_SHORT, timer.time_left))
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
		cancelTimer()

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