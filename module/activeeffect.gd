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
	SignalBus.getSignal("dispel_"+flag).connect(ae._on_dispelled)
	SignalBus.getSignal("dispel_all_effects").connect(ae._on_dispelled)
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
	FlagManager.clearFlag("last_mana_transaction_succeeded")
	FlagManager.clearFlag("last_used_local_mana_balance")
	if is_queued_for_deletion():
		return

	var manaStored:float = FlagManager.getTotalCountAmount("mana")
	print("Stored mana: ", manaStored, "; Cost: ", CONSTANTS.DISPEL_MANA_COST)
	if manaStored >= CONSTANTS.DISPEL_MANA_COST:
		# Use local mana storage
		FlagManager.setFlag("last_used_local_mana_balance")
		SignalBus.getSignal("display_mana").emit()
		SignalBus.getSignal("display_mana_cost").emit()
		FlagManager.HANDLERS.WORLD.setFlag("mana_cost", CONSTANTS.DISPEL_MANA_COST)
		FlagManager.HANDLERS.WORLD.count("mana", "spent", -CONSTANTS.DISPEL_MANA_COST, true)
		print("Using %s local mana"%CONSTANTS.DISPEL_MANA_COST, "... We now have %s mana"%FlagManager.getTotalCountAmount("mana"))
		_on_successful_dispel()
	elif FlagManager.isFlagSet("energy_link"):
		# Queue it in a mana transaction
		DracominoUtil.tryEnergyLinkManaTransaction(CONSTANTS.DISPEL_MANA_COST, _on_successful_dispel)
	else:
		FlagManager.HANDLERS.WORLD.setFlag("mana_cost", CONSTANTS.DISPEL_MANA_COST)
		SignalBus.getSignal("display_mana").emit()
		SignalBus.getSignal("display_mana_cost").emit()
		print("Did not have enough mana to dispel effect")

func _on_successful_dispel() -> void:
	FlagManager.setFlag("last_mana_transaction_succeeded")
	SoundManager.play("untrap")
	queue_free()
