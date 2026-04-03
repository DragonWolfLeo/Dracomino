class_name ActiveEffect extends FlagHolder

var durationLeft:int = 10

# === Static functions ===
static func instantiateEffect(flag:String, duration:int = 10) -> ActiveEffect:
	var ae := ActiveEffect.new()
	ae.priority = FlagHolder.PRIORITY.OBJECT
	ae.durationLeft = duration
	ae.tree_entered.connect(ae.setFlag.bind(flag), CONNECT_ONE_SHOT)
	return ae

# === Virtuals ===
func _ready() -> void:
	SignalBus.getSignal("effect_duration_down").connect(_on_piece_locked, CONNECT_DEFERRED)

func _on_piece_locked() -> void:
	durationLeft -= 1
	if durationLeft <= 0:
		queue_free()
