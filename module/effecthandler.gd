class_name EffectHandler extends Node

var bufferedEffects:Array[DracominoHandler.StateItem] = []
var deferredEffects:Array[DracominoHandler.StateItem] = [] ## Cutscenes saved for when you restart because it wasn't a good time
var _NOOP:Callable = func(): pass

class Effect:
	var triggerFn:Callable
	var canTriggerFn:Callable = func(): return true
	var playTrapSound:bool = true
	func _init(_triggerFn:Callable) -> void:
		triggerFn = _triggerFn
	func setCanTriggerFn(fn:Callable) -> Effect:
		canTriggerFn = fn
		return self
	func setTrapSound(enabled:bool = true) -> Effect:
		playTrapSound = enabled
		return self

var EFFECTS:Dictionary[StringName, Effect] = {
	tutorial = Effect.new(_NOOP),
	logic_tutorial = Effect.new(_NOOP),
	fishing = Effect.new(setMode.bind("fishing")).setCanTriggerFn(func(): return FlagManager.getTotalCountAmount("shapes_left") >= 2),
	egg = Effect.new(_NOOP),
	welldone = Effect.new(_NOOP),
	crystal_trap = Effect.new(_NOOP),
	invertcolors_trap = Effect.new(_NOOP),
	water_trap = Effect.new(_NOOP),
	pixellation_trap = Effect.new(_NOOP),
	fracture_trap = Effect.new(_NOOP),
	zoom_trap = Effect.new(_NOOP),
	impatience_trap = Effect.new(_NOOP),
	commitment_trap = Effect.new(_NOOP),
}

# === Static functions ===
static func setMode(modeName:StringName):
	SignalBus.getSignal("mode_set_requested", modeName).emit()

#  === Functions ===
func hasEffectsBuffered() -> bool:
	return not bufferedEffects.is_empty()

func on_board_reset() -> void:
	# Give deferred effects another chance
	bufferedEffects.clear()
	bufferedEffects.append_array(deferredEffects)
	deferredEffects.clear()

func bufferEffect(stateItem:DracominoHandler.StateItem) -> void:
	if stateItem and not bufferedEffects.has(stateItem):
		bufferedEffects.append(stateItem)

func tryToTriggerNextEffect() -> DracominoHandler.StateItem: ## true = success, false = failure
	if bufferedEffects.size():
		var popped:DracominoHandler.StateItem = bufferedEffects.pop_front() as DracominoHandler.StateItem
		if popped and popped.data:
			var fx:Effect = EFFECTS.get(popped.data.internalName)
			if fx:
				if fx.canTriggerFn.call():
					fx.triggerFn.call()
					if fx.playTrapSound:
						SoundManager.play("trap")
					return popped
				else:
					deferredEffects.append(popped)
					return tryToTriggerNextEffect()
	return null
