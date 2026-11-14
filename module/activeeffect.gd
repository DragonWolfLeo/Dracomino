class_name ActiveEffect extends FlagHolder

signal duration_changed(remaining:int)

var durationLeft:float = -1
var dispelCost:float = CONSTANTS.DISPEL_MANA_COST
var effectDurationTick_cooldown:float = 2.0
var _cooldownTimer:SceneTreeTimer

static var DEFAULT_TICK_SIGNAL_FLAG:StringName = ""
static var DEFAULT_TICK_SIGNAL_KEY:StringName = "effect_duration_down"

# === Static functions ===
static func instantiateEffect(flag:String, duration:float = -1, annoying:bool = true, removalAction:String = "dispel") -> ActiveEffect:
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

func tickDuration(amount:float, affectedByCooldown:bool = true) -> void:
	if affectedByCooldown and _cooldownTimer:
		return
	durationLeft -= amount
	if durationLeft <= 0:
		queue_free()
	else:
		duration_changed.emit(durationLeft)
		_cooldownTimer = get_tree().create_timer(effectDurationTick_cooldown, true)
		_cooldownTimer.timeout.connect(set.bind("_cooldownTimer", null))

func connectTickSignal(sig:Signal, tickAmount:float = 1, affectedByCooldown:bool = true) -> ActiveEffect: ## Connect a signal to tick duration
	if not sig.is_connected(_on_effect_duration_down):
		sig.connect(_on_effect_duration_down, CONNECT_DEFERRED)
	return self

func connectDefaultTickSignal() -> ActiveEffect: ## Connect the signal effect_duration_down to tick duration
	connectTickSignal(SignalBus.getSignal(DEFAULT_TICK_SIGNAL_KEY, DEFAULT_TICK_SIGNAL_FLAG))
	return self

# === Events ===
func _on_effect_duration_down(tickAmount:float = 1, affectedByCooldown:bool = true) -> void:
	tickDuration(tickAmount, affectedByCooldown)

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
