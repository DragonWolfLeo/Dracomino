class_name EffectHandler extends Node

var bufferedEffects:Array[DracominoHandler.StateItem] = []
static var _NOOP:Callable = func(_null:Variant = null): pass

signal effect_activated(item:DracominoHandler.StateItem)

static var bufferedBoardEffects:Array[BoardEffect] = []

class Effect:
	var triggerFn:Callable
	var canTriggerFn:Callable = func(): return true
	var blockRequestPiece:bool = false
	var context:Array[StringName] = []
	func _init(fn:Callable) -> void:
		triggerFn = fn
	func setCanTriggerFn(fn:Callable) -> Effect:
		canTriggerFn = fn
		return self
	func setBlockRequestPiece(block:bool = true) -> Effect:
		blockRequestPiece = block
		return self
	func addContext(tag:StringName) -> Effect:
		if not context.has(tag):
			context.append(tag)
		return self
	func matchesContext(ctxMask:Array[StringName]) -> bool:
		if ctxMask.has("all"):
			return true
		for tag in context:
			if not ctxMask.has(tag):
				return false
		return true

class BoardEffect extends Effect:
	var boardTriggerFn:Callable
	var boardCanTriggerFn:Callable = func(board:Board): return true
	var makesPiece:bool = false
	func _init(boardFn:Callable) -> void:
		boardTriggerFn = boardFn
		triggerFn = _queueEffect
	func _queueEffect() -> void:
		EffectHandler.bufferedBoardEffects.append(self)
		SignalBus.getSignal("boardeffect_queued").emit()
	func setCanTriggerFn(boardFn:Callable) -> BoardEffect:
		boardCanTriggerFn = boardFn
		return self
	func setMakesPiece(value:bool = true) -> BoardEffect:
		makesPiece = value
		return self

var EFFECTS:Dictionary[StringName, Effect] = {
	tutorial = Effect.new(_loadDialogue.bind("tutorial"))\
		.setCanTriggerFn(_canLoadNewDialogue),
	logic_tutorial = Effect.new(_loadDialogue.bind("tutorial_logic"))\
		.setCanTriggerFn(_canLoadNewDialogue),
	fishing = Effect.new(_setMode.bind("fishing"))\
		.setCanTriggerFn(combineFunctions.bind(_piecesAreLeft.bind(2), FlagManager.isFlagSet.bind("!mode=fishing"))).setBlockRequestPiece(),
	welldone = Effect.new(_activateEffect.bind("overlay_welldone", 3, false)).addContext("line_clear"),
	crystal_trap = Effect.new(_activateEffect.bind("overlay_crystal", 4)),
	invertcolors_trap = Effect.new(_activateEffect.bind("overlay_invert")),
	water_trap = Effect.new(_activateEffect.bind("overlay_water")),
	pixellation_trap = Effect.new(_activateEffect.bind("overlay_pixel", 6)),
	fracture_trap = Effect.new(_activateEffect.bind("overlay_fracture")),
	zoom_trap = Effect.new(_activateEffect.bind("effect_zoom", 4, false)), # Not "annoying" because doesn't affect the logic tutorial
	impatience_trap = Effect.new(SignalBus.getSignal("effect_impatience").emit)\
		.setCanTriggerFn(_canSpawnMoreShapes).addContext("delayed"),
	space_trap = Effect.new(_activateEffect.bind("effect_space", 8, false)),
	noop = Effect.new(_NOOP),

	# == Trap Link Specific ==
	fade = Effect.new(_fade),
	random_trap = Effect.new(_randomTrap),

	# == Board Effects ==
	egg = BoardEffect.new(_board_instantSpawn.bind("egg")).setCanTriggerFn(_canSpawnMoreShapes.unbind(1)).setMakesPiece(),
	enchantment_curse = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment_curse")).addContext("on_spawn"),
	enchantment_curse_gravity = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment_curse_gravity"))\
		.setCanTriggerFn(_board_canEnchantPiece).addContext("on_spawn"),
	enchantment_curse_movement = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment_curse_movement"))\
		.setCanTriggerFn(_board_canEnchantPiece).addContext("on_spawn"),
	enchantment_legendary_movement = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment_legendary_movement"))\
		.setCanTriggerFn(_board_canEnchantPiece).addContext("on_spawn"),
	enchantment_legendary_spin = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment_legendary_spin"))\
		.setCanTriggerFn(_board_canEnchantPiece).addContext("on_spawn"),
	enchantment = BoardEffect.new(_board_enchantCurrentPiece.bind("enchantment"))\
		.setCanTriggerFn(_board_canEnchantPiece).addContext("on_spawn"),
}

# === Static helpers ===
static func combineFunctions(a:Callable, b:Callable) -> bool:
	return a.call() and b.call()

# === Private functions ===
func _setMode(modeName:StringName) -> void:
	SignalBus.getSignal("mode_set_requested", modeName).emit()

func _piecesAreLeft(amount:int) -> bool:
	return FlagManager.getTotalCountAmount("shapes_left") >= amount

func _canSpawnMoreShapes() -> bool:
	return _piecesAreLeft(3) and FlagManager.getTotalCountAmount("shapes_active") < 5

func _loadDialogue(dialogue:Variant) -> void:
	DialogueManager.loadDialogue(dialogue)

func _canLoadNewDialogue() -> bool:
	return DialogueManager.dialogue == null

func _activateEffect(flag:String, duration:int = 8, annoying:bool = true) -> void:
	var ae:ActiveEffect = ActiveEffect.instantiateEffect(flag, duration, annoying)
	add_child(ae)

func _board_instantSpawn(board:Board, internalName:StringName) -> void:
	var stateItem:DracominoHandler.StateItem = DracominoHandler.StateItem.fromInternalName(internalName)
	stateItem.usedTrapLink = true # Prevent from spawning traps like this
	board.createPiece(DracominoHandler.PieceContext.new(stateItem).setInstantSpawn())
	SoundManager.play("trap")

func _board_enchantCurrentPiece(board:Board, enchantmentName:StringName) -> void:
	var piece:Piece = board.getFocusPiece()
	if not piece or piece.rarity:
		return
	var enchantment:Piece.Enchantment = piece.applyEnchantmentByName(enchantmentName)
	if enchantment is Piece.Enchantment:
		SoundManager.play("trap")

func _board_canEnchantPiece(board:Board) -> bool:
	var piece:Piece = board.getFocusPiece()
	if piece and piece.rarity:
		return false
	return true

func _fade() -> void:
	Overlay.doFade(1.5, 1.5)

func _randomTrap():
	var validTraps:Array[Effect] = []
	for effectName in CONSTANTS.RANDOM_TRAP_CHOICES:
		var fx:Effect = EFFECTS.get(effectName)
		if fx is Effect and fx.canTriggerFn.call():
			validTraps.append(fx)
	if validTraps.size():
		(validTraps.pick_random() as Effect).triggerFn.call()

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

func getNextValidBufferedEffect(context:Array[StringName] = []) -> DracominoHandler.StateItem:
	var ret:bool = false
	for stateItem in bufferedEffects:
		var fx:Effect = getEffectObject(stateItem)
		if fx and fx.canTriggerFn.call() and not stateItem.used and fx.matchesContext(context):
			return stateItem
	return null

func willBlockRequestPiece(stateItem:DracominoHandler.StateItem, ignoreUsed:bool = false) -> bool:
	if stateItem == null or (stateItem.used and not ignoreUsed):
		return false
	var fx:Effect = getEffectObject(stateItem)
	return fx and fx.canTriggerFn.call() and fx.blockRequestPiece

func tryToTriggerNextEffect(context:Array[StringName] = []) -> DracominoHandler.StateItem: ## Returns triggered state item on success
	if FlagManager.isFlagSet("gameover"):
		return null

	var nextEffect: DracominoHandler.StateItem = getNextValidBufferedEffect(context)
	if nextEffect:
		# No verification needed since next effect is guaranteed valid
		var fx:Effect = getEffectObject(nextEffect)
		fx.triggerFn.call()
		nextEffect.used = true
		effect_activated.emit(nextEffect)
		bufferedEffects.erase(nextEffect)
		return nextEffect
	return null

func tryToTriggerEffect(stateItem:DracominoHandler.StateItem, bufferOnFailure:bool = true, context:Array[StringName] = []) -> bool: ## Returns true on success
	if FlagManager.isFlagSet("gameover"):
		return false
	if stateItem:
		if stateItem.used:
			return false
		var fx:Effect = getEffectObject(stateItem)
		if fx:
			if fx.canTriggerFn.call() and fx.matchesContext(context):
				fx.triggerFn.call()
				stateItem.used = true
				effect_activated.emit(stateItem)
				return true
			elif bufferOnFailure:
				bufferedEffects.append(stateItem)
	return false


func triggerEffectByName(effectName:StringName) -> bool: ## Returns true on success
	if FlagManager.isFlagSet("gameover"):
		return false
	var fx:Effect = EFFECTS.get(effectName)
	if fx:
		if fx.canTriggerFn.call():
			fx.triggerFn.call()
			return true
	return false

# === Static Board Functions ===
static func getNextValidBufferedBoardEffect(board:Board, context:Array[StringName] = []) -> BoardEffect:
	var ret:bool = false
	for fx in bufferedBoardEffects:
		if fx and fx.boardCanTriggerFn.call(board) and fx.matchesContext(context):
			return fx
	return null

static func tryToTriggerNextBoardEffect(board:Board, context:Array[StringName] = []) -> BoardEffect: ## Returns triggered effect on success
	if FlagManager.isFlagSet("gameover"):
		return null
	var fx:BoardEffect = getNextValidBufferedBoardEffect(board, context)
	if fx:
		# No verification needed since next effect is guaranteed valid
		fx.boardTriggerFn.call(board)
		bufferedBoardEffects.erase(fx)
		return fx
	return null

static func hasValidBufferedBoardEvent(board:Board) -> bool:
	return getNextValidBufferedBoardEffect(board) != null