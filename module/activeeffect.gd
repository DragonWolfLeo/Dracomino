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

var dispelCost:float = CONSTANTS.DISPEL_MANA_COST
var _cooldownTimer:SceneTreeTimer
var EFFECT_DURATION_TICK_COOLDOWN:float = 2.0

# === Static functions ===
static func instantiateEffect(flag:String, duration:int = -1, annoying:bool = true, removalAction:String = "dispel") -> ActiveEffect:
	var ae := ActiveEffect.new()
	ae.priority = FlagHolder.PRIORITY.OBJECT
	ae.durationLeft = duration
	var _setflags = func():
		ae.setFlag(flag)
		ae.count("effects_active", flag, 1)
		if annoying:
			ae.count("annoying_effects_active", flag, 1)
			SignalBus.getSignal("dispel_annoying_effects").connect(ae._on_dispelled)
			SignalBus.getSignal("dispel_annoying_effects_free").connect(ae.clearEffect)
	ae.tree_entered.connect(_setflags, CONNECT_ONE_SHOT)
	# Priced versions
	SignalBus.getSignal(removalAction+"_"+flag).connect(ae._on_dispelled)
	SignalBus.getSignal(removalAction+"_effects").connect(ae._on_dispelled)
	SignalBus.getSignal("dispel_all_effects").connect(ae._on_dispelled)
	# Free versions
	SignalBus.getSignal(removalAction+"_"+flag+"_free").connect(ae.clearEffect)
	SignalBus.getSignal(removalAction+"_effects_free").connect(ae.clearEffect)
	SignalBus.getSignal("dispel_all_effects_free").connect(ae.clearEffect)
	return ae

func clearEffect() -> void:
	SoundManager.play("untrap")
	queue_free()

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
	FlagManager.HANDLERS.WORLD.clearFlag("mana_cost") # Clear this now, but defer cost calculation so we get an accurate value
	if is_queued_for_deletion():
		return
		
	var manaStored:float = FlagManager.getTotalCountAmount("mana")
	if manaStored >= dispelCost:
		# Use local mana storage
		FlagManager.setFlag("last_used_local_mana_balance")
		SignalBus.getSignal("display_mana").emit()
		SignalBus.getSignal("display_mana_cost").emit.call_deferred()
		FlagManager.HANDLERS.WORLD.count.call_deferred("mana_cost", "cost", dispelCost, true)
		FlagManager.HANDLERS.WORLD.count("mana", "spent", -dispelCost, true)
		print.call_deferred("Using %s local mana"%dispelCost, "... We now have %s mana"%FlagManager.getTotalCountAmount("mana"))
		_on_successful_dispel()
	elif FlagManager.isFlagSet("energy_link"):
		# Queue it in a mana transaction
		DracominoUtil.tryEnergyLinkManaTransaction(dispelCost, _on_successful_dispel)
	else:
		FlagManager.HANDLERS.WORLD.count.call_deferred("mana_cost", "cost", dispelCost, true)
		SignalBus.getSignal("display_mana").emit()
		SignalBus.getSignal("display_mana_cost").emit.call_deferred()
		print("Did not have enough mana to dispel effect")

func _on_successful_dispel() -> void:
	FlagManager.setFlag("last_mana_transaction_succeeded")
	clearEffect()
