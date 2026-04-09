class_name ActiveEffect extends FlagHolder

var durationLeft:int = -1:
	set(value):
		if durationLeft == value:
			return
		durationLeft = value
		var sig:Signal = SignalBus.getSignal("effect_duration_down")
		if durationLeft > 0:
			if not sig.is_connected(_on_effect_duration_down):
				sig.connect(_on_effect_duration_down, CONNECT_DEFERRED)
		else:
			if sig.is_connected(_on_effect_duration_down):
				sig.disconnect(_on_effect_duration_down)

var _cooldownTimer:SceneTreeTimer
var EFFECT_DURATION_TICK_COOLDOWN:float = 2.0

# === Static functions ===
static func instantiateEffect(flag:String, duration:int = -1) -> ActiveEffect:
	var ae := ActiveEffect.new()
	ae.priority = FlagHolder.PRIORITY.OBJECT
	ae.durationLeft = duration
	ae.tree_entered.connect(ae.setFlag.bind(flag), CONNECT_ONE_SHOT)
	ae.tree_entered.connect(ae.count.bind("effects_active", flag, 1), CONNECT_ONE_SHOT)
	SignalBus.getSignal("dispel_"+flag).connect(ae._on_dispelled, CONNECT_ONE_SHOT)
	SignalBus.getSignal("dispel_all_effects").connect(ae._on_dispelled, CONNECT_ONE_SHOT)
	return ae

# === Events ===
func _on_effect_duration_down() -> void:
	if _cooldownTimer:
		return
	durationLeft -= 1
	if durationLeft <= 0:
		queue_free()
	else:
		_cooldownTimer = get_tree().create_timer(EFFECT_DURATION_TICK_COOLDOWN, true)
		_cooldownTimer.timeout.connect(set.bind("_cooldownTimer", null))

func _on_dispelled() -> void:
	if is_queued_for_deletion():
		return
	SoundManager.play("untrap")
	queue_free()
