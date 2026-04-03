class_name EffectHandler extends Node

var bufferedEffects:Array[DracominoHandler.StateItem] = []
var deferredEffects:Array[DracominoHandler.StateItem] = [] ## Cutscenes saved for when you restart because it wasn't a good time
var _NOOP:Callable = func(): pass

class Effect:
	var triggerFn:Callable
	var canTriggerFn:Callable = func(): return true
	var playTrapSound:bool = false
	func _init(_triggerFn:Callable) -> void:
		triggerFn = _triggerFn
	func setCanTriggerFn(fn:Callable) -> Effect:
		canTriggerFn = fn
		return self
	func setTrapSound(enabled:bool = true) -> Effect:
		playTrapSound = enabled
		return self
	func noTrapSound() -> Effect:
		playTrapSound = false
		return self

var EFFECTS:Dictionary[StringName, Effect] = {
	tutorial = Effect.new(_loadDialogue.bind("tutorial")),
	logic_tutorial = Effect.new(_loadDialogue.bind("tutorial_logic")),
	fishing = Effect.new(_setMode.bind("fishing")).setCanTriggerFn(func(): return FlagManager.getTotalCountAmount("shapes_left") >= 2),
	welldone = Effect.new(_activateEffect.bind("overlay_welldone", 3)),
	crystal_trap = Effect.new(_activateEffect.bind("overlay_crystal", 5)),
	invertcolors_trap = Effect.new(_activateEffect.bind("overlay_invert")),
	water_trap = Effect.new(_activateEffect.bind("overlay_water")),
	pixellation_trap = Effect.new(_activateEffect.bind("overlay_pixel")),
	fracture_trap = Effect.new(_activateEffect.bind("overlay_fracture")),
	zoom_trap = Effect.new(_activateEffect.bind("effect_zoom", 2)),
	impatience_trap = Effect.new(SignalBus.getSignal("effect_impatience").emit),
	commitment_trap = Effect.new(FlagManager.HANDLERS.LEVEL.setFlag.bind("committed")),
	noop = Effect.new(_NOOP),
}

# === Private functions ===
func _setMode(modeName:StringName):
	SignalBus.getSignal("mode_set_requested", modeName).emit()
	FlagManager.HANDLERS.LEVEL.setFlag("committed")

func _loadDialogue(dialogue:Variant):
	DialogueManager.loadDialogue(dialogue)

func _activateEffect(flag:String, duration:int = 10):
	var ae:ActiveEffect = ActiveEffect.instantiateEffect(flag, duration)
	add_child(ae)

# === Virtuals ===
func _ready() -> void:
	name = "EffectHandler"

#  === Functions ===
func hasEffectsBuffered() -> bool:
	return not bufferedEffects.is_empty()

func on_board_reset() -> void:
	# Give deferred effects another chance
	bufferedEffects.clear()
	bufferedEffects.append_array(deferredEffects)
	deferredEffects.clear()
	# Get rid of active effects
	for child in get_children():
		if child is ActiveEffect:
			child.queue_free()

func fullClear() -> void: ## To be used when loading a new seed
	bufferedEffects.clear()
	deferredEffects.clear()

func bufferEffect(stateItem:DracominoHandler.StateItem) -> void:
	if stateItem and not bufferedEffects.has(stateItem):
		bufferedEffects.append(stateItem)

func tryToTriggerNextEffect() -> DracominoHandler.StateItem: ## Returns triggered state item on success
	if FlagManager.isFlagSet("gameover"):
		return null
	if bufferedEffects.size():
		var popped:DracominoHandler.StateItem = bufferedEffects.pop_front() as DracominoHandler.StateItem
		if popped and popped.data:
			var fx:Effect = EFFECTS.get(popped.data.internalName)
			if fx:
				if popped.used:
					return tryToTriggerNextEffect()
				elif fx.canTriggerFn.call():
					fx.triggerFn.call()
					if fx.playTrapSound:
						SoundManager.play("trap")
					popped.used = true
					return popped
				else:
					deferredEffects.append(popped)
			return tryToTriggerNextEffect()
	return null

func tryToTriggerEffect(stateItem:DracominoHandler.StateItem) -> bool: ## Returns true on success
	if FlagManager.isFlagSet("gameover"):
		return false
	if stateItem and stateItem.data:
		if stateItem.used:
			return false
		var fx:Effect = EFFECTS.get(stateItem.data.internalName)
		if fx:
			if fx.canTriggerFn.call():
				fx.triggerFn.call()
				if fx.playTrapSound:
					SoundManager.play("trap")
				stateItem.used = true
				return true
			else:
				bufferedEffects.append(stateItem)
	return false

func triggerEffectImmediately(stateItem:DracominoHandler.StateItem) -> bool: ## Returns true on success
	if FlagManager.isFlagSet("gameover"):
		return false
	if stateItem and stateItem.data:
		var fx:Effect = EFFECTS.get(stateItem.data.internalName)
		if fx:
			if fx.canTriggerFn.call():
				fx.triggerFn.call()
				if fx.playTrapSound:
					SoundManager.play("trap")
				return true
	return false
