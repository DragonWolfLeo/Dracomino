class_name EffectHandler extends Node

var bufferedEffects:Array[DracominoHandler.StateItem] = []
var _NOOP:Callable = func(): pass

signal effect_activated(item:DracominoHandler.StateItem)

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
	bufferedEffects.clear()
	# Get rid of active effects
	for child in get_children():
		if child is ActiveEffect:
			child.queue_free()

func bufferEffect(stateItem:DracominoHandler.StateItem) -> void:
	if stateItem and not stateItem.used and not bufferedEffects.has(stateItem):
		bufferedEffects.append(stateItem)

func getEffectObject(stateItem:DracominoHandler.StateItem) -> Effect:
	if stateItem and stateItem.data:
		if stateItem.used:
			return null
		return EFFECTS.get(stateItem.data.internalName)
	return null

func hasValidBufferedEvent() -> bool:
	return getNextValidBufferedEffect() != null

func getNextValidBufferedEffect() -> DracominoHandler.StateItem:
	var ret:bool = false
	for stateItem in bufferedEffects:
		var fx:Effect = getEffectObject(stateItem)
		if fx and fx.canTriggerFn.call() and not stateItem.used:
			return stateItem
	return null

func willBlockRequestPiece(stateItem:DracominoHandler.StateItem, ignoreUsed:bool = false) -> bool:
	if stateItem == null or (stateItem.used and not ignoreUsed):
		return false
	var fx:Effect = getEffectObject(stateItem)
	return fx and fx.canTriggerFn.call() and fx.blockRequestPiece

func tryToTriggerNextEffect() -> DracominoHandler.StateItem: ## Returns triggered state item on success
	if FlagManager.isFlagSet("gameover"):
		return null

	var nextEffect: DracominoHandler.StateItem = getNextValidBufferedEffect()
	if nextEffect:
		# No verification needed since next effect is guaranteed valid
		var fx:Effect = getEffectObject(nextEffect)
		fx.triggerFn.call()
		if fx.playTrapSound:
			SoundManager.play("trap")
		nextEffect.used = true
		effect_activated.emit(nextEffect)
		bufferedEffects.erase(nextEffect)
		return nextEffect
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
				effect_activated.emit(stateItem)
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
			effect_activated.emit(stateItem)
			return true
	return false
