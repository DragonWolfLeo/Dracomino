class_name EffectHandler extends Node

var bufferedEffects:Array[DracominoHandler.StateItem] = []
var deferredEffects:Array[DracominoHandler.StateItem] = [] ## Cutscenes saved for when you restart because it wasn't a good time
var _NOOP:Callable = func(): pass

class Effect:
	var triggerFn:Callable
	var canTriggerFn:Callable = func(): return true
	var playTrapSound:bool = false
	var blockRequestPiece:bool = false
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
	func setBlockRequestPiece(block:bool = true) -> Effect:
		blockRequestPiece = block
		return self


var EFFECTS:Dictionary[StringName, Effect] = {
	tutorial = Effect.new(_loadDialogue.bind("tutorial")).setCanTriggerFn(_canLoadNewDialogue),
	logic_tutorial = Effect.new(_loadDialogue.bind("tutorial_logic")).setCanTriggerFn(_canLoadNewDialogue),
	fishing = Effect.new(_setMode.bind("fishing")).setCanTriggerFn(_piecesAreLeft.bind(2)).setBlockRequestPiece(),
	welldone = Effect.new(_activateEffect.bind("overlay_welldone", 3)),
	crystal_trap = Effect.new(_activateEffect.bind("overlay_crystal", 4)),
	invertcolors_trap = Effect.new(_activateEffect.bind("overlay_invert")),
	water_trap = Effect.new(_activateEffect.bind("overlay_water")),
	pixellation_trap = Effect.new(_activateEffect.bind("overlay_pixel", 6)),
	fracture_trap = Effect.new(_activateEffect.bind("overlay_fracture")),
	zoom_trap = Effect.new(_activateEffect.bind("effect_zoom", 2)),
	impatience_trap = Effect.new(SignalBus.getSignal("effect_impatience").emit),
	commitment_trap = Effect.new(_activateEffect.bind("committed", -1)),
	noop = Effect.new(_NOOP),
}

# === Private functions ===
func _setMode(modeName:StringName) -> void:
	SignalBus.getSignal("mode_set_requested", modeName).emit()

func _piecesAreLeft(amount:int) -> bool:
	return FlagManager.getTotalCountAmount("shapes_left") >= amount

func _loadDialogue(dialogue:Variant) -> void:
	DialogueManager.loadDialogue(dialogue)

func _canLoadNewDialogue() -> bool:
	return DialogueManager.dialogue == null

func _activateEffect(flag:String, duration:int = 8) -> void:
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

func getEffectObject(stateItem:DracominoHandler.StateItem) -> Effect:
	if stateItem and stateItem.data:
		if stateItem.used:
			return null
		return EFFECTS.get(stateItem.data.internalName)
	return null

func canTriggerAnyBufferedEvent() -> bool:
	var ret:bool = false
	for stateItem in bufferedEffects:
		var fx:Effect = getEffectObject(stateItem)
		if fx and fx.canTriggerFn.call() and not stateItem.used:
			return true
	return ret

func willBlockRequestPiece(stateItem:DracominoHandler.StateItem) -> bool:
	if stateItem == null or stateItem.used:
		return false
	var fx:Effect = getEffectObject(stateItem)
	return fx and fx.canTriggerFn.call() and fx.blockRequestPiece

func tryToTriggerNextEffect() -> DracominoHandler.StateItem: ## Returns triggered state item on success
	if FlagManager.isFlagSet("gameover"):
		return null
	if bufferedEffects.size():
		var popped:DracominoHandler.StateItem = bufferedEffects.pop_front() as DracominoHandler.StateItem
		var fx:Effect = getEffectObject(popped)
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
	if stateItem:
		if stateItem.used:
			return false
		var fx:Effect = getEffectObject(stateItem)
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
	var fx:Effect = getEffectObject(stateItem)
	if fx:
		if fx.canTriggerFn.call():
			fx.triggerFn.call()
			if fx.playTrapSound:
				SoundManager.play("trap")
			return true
	return false
