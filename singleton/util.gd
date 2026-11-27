class_name DracominoUtil # TODO: Rename to Util when cleaning up GodotAP
extends Node

# === Helpers ===
static func setToArray(_set:Dictionary) -> Array: ## Converts a Dictionary[Variant, bool] to Array with all keys mapped to true
	var array:Array = []
	for k:Variant in _set.keys():
		if _set[k]: array.append(k)
	return array

static func arrayToIntSet(array:Array) -> Dictionary[int, bool]: ## Converts an Array of ints to a Dictionary[int, bool]
	var intSet:Dictionary[int, bool] = {}
	for v:Variant in array:
		intSet[int(v)] = true
	return intSet

# Death Link Messages
class DeathLinkMessageTemplate:
	var messageTemplate:String
	var templateFormatValues:Dictionary
	var contextTags:Array[String]
	func _init(_messageTemplate:String = "{player} died"):
		messageTemplate = _messageTemplate
		templateFormatValues = CONSTANTS.CONTEXT_TAGS.GENERIC.duplicate()

	func addContext(_contextTag:StringName) -> DeathLinkMessageTemplate:
		# TODO: Use variadic arguments when upgrading to Godot 4.5
		assert(
			_contextTag in CONSTANTS.CONTEXT_TAGS,
			"DeathLinkMessageTemplate.addContext error: Context tag {_contextTag} in not in CONSTANTS.CONTEXT_TAGS!".format({_contextTag=_contextTag})
		)
		templateFormatValues.merge(CONSTANTS.CONTEXT_TAGS.get(_contextTag, {}), true)
		contextTags.append(_contextTag)
		return self
	
	func addContexts(_contextTags:Array) -> DeathLinkMessageTemplate:
		for tag in _contextTags:
			addContext(tag)
		return self


static func generateDeathlinkMessage(category:String = "TOP", contextTags:Array = [], formatValues:Dictionary = {}) -> String:
	if not category in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES:
		printerr("DracominoUtil.generateDeathlinkMessage error: {category} not found in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES!".format({category=category}))
	var validTemplates:Array[DeathLinkMessageTemplate] = []
	for template in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES.get(category, []):
		if template is DeathLinkMessageTemplate:
			if template.contextTags.size():
				var skip:bool = false
				for tag in template.contextTags:
					if not tag in contextTags:
						skip = true
						break
				if skip: continue
			validTemplates.append(template)
	
	# Choose a random valid template
	var message:String = "{player} died."
	if validTemplates.size():
		var template = validTemplates[randi_range(0, validTemplates.size() - 1)]
		formatValues = formatValues.merged(template.templateFormatValues)
		message = template.messageTemplate
	else:
		printerr("DracominoUtil.generateDeathlinkMessage error: No death link message templates are valid with category ", category, " and tags ", contextTags) 

	message = message.format(formatValues)
	return message

static func getPronouns() -> Dictionary: ## Get pronouns from settings
	var ret:Dictionary = {
		his_her_their = str(Config.getSetting("pronouns_his_her_their", "")).to_lower(),
		him_her_them = str(Config.getSetting("pronouns_him_her_them", "")).to_lower(),
		he_she_they = str(Config.getSetting("pronouns_he_she_they", "")).to_lower(),
	}
	if not ret.get("his_her_their"): ret["his_her_their"] = "their"
	if not ret.get("him_her_them"): ret["him_her_them"] = "them"
	if not ret.get("he_she_they"): ret["he_she_they"] = "they"
	return ret

class DeathContext:
	var category:String
	var itemContext:DracominoHandler.PieceContext
	var contextTags:Array[String]
	var formatValues:Dictionary = {}
	func _init(_category:String, _itemContext:DracominoHandler.PieceContext = null) -> void:
		if _category in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES:
			category = _category
		else:
			printerr("DeathContext._init error: {category} is not a valid category!".format({category=_category}))
		itemContext = _itemContext

	func addContext(_contextTag:StringName) -> DeathContext:
		# TODO: Use variadic arguments when upgrading to Godot 4.5
		if _contextTag in CONSTANTS.CONTEXT_TAGS:
			contextTags.append(_contextTag)
		else:
			printerr("DeathContext.addContext error: {contextTag} is not a valid context tag!".format({contextTags=_contextTag}))
		return self
	
	func addContexts(_contextTags:Array) -> DeathContext:
		for tag in _contextTags:
			addContext(tag)
		return self

# Mode stuff
static func getParentMode(node:Node) -> Mode:
	while node and not node is Mode:
		node = node.get_parent()
	return node

# Energy Link Stuff
class EnergyLinkTransactionContext:
	var manaCost:float = 0
	var onSuccess:Callable
	func _init(_manaCost:float, _onSuccess:Callable) -> void:
		manaCost = _manaCost
		onSuccess = _onSuccess

static var _bufferedTransactionFns:Array[EnergyLinkTransactionContext]
static var _bufferedTransactionLifetimeTween:Tween
static func tryEnergyLinkManaTransaction(manaCost:float, onSuccess:Callable) -> void:
	if Archipelago.conn and FlagManager.isFlagSet("energy_link"):
		# Defer a check for bank balance and decide if we can make transaction
		Archipelago.conn.retrieve.call_deferred("EnergyLink" + str(Archipelago.conn.team_id), makeEnergyLinkTransaction)
		# Add to the buffer and make lifetime tween
		_bufferedTransactionFns.append(EnergyLinkTransactionContext.new(manaCost, onSuccess))
		if _bufferedTransactionLifetimeTween:
			_bufferedTransactionLifetimeTween.kill()
		_bufferedTransactionLifetimeTween = Game.create_tween()
		_bufferedTransactionLifetimeTween.tween_callback(_bufferedTransactionFns.clear).set_delay(5.0)
	else:
		_bufferedTransactionFns.clear()
		print("EnergyLink transaction failed: not connected or EnergyLink is disabled!")

static func makeEnergyLinkTransaction(energyBankBalance:Variant) -> void:
	FlagManager.HANDLERS.WORLD.clearFlag("mana_cost")
	FlagManager.HANDLERS.WORLD.clearFlag("energy_cost")
	if not(energyBankBalance is float or energyBankBalance is int):
		return
	FlagManager.setFlag("last_known_energy_bank_balance", energyBankBalance)
	SignalBus.getSignal("display_energy").emit()
	SignalBus.getSignal("display_mana").emit()
	if not _bufferedTransactionFns.size():
		return
	_bufferedTransactionLifetimeTween.kill()
	var bufferedTransactionFns = _bufferedTransactionFns.duplicate()
	_bufferedTransactionFns.clear()
	var approvedSuccessFns:Array[Callable] = []

	# Get energy cost all added up
	var energyCost:float = 0
	var manaCost:float = 0
	var attemptedEnergyCost:float = 0
	var attemptedManaCost:float = 0
	var storedMana:float = FlagManager.getTotalCountAmount("mana")
	for transaction:EnergyLinkTransactionContext in bufferedTransactionFns:
		if not transaction.onSuccess.is_valid():
			# The parent node will freed before we had to chance to call this
			continue

		# Figure out how much mana will be spent on this
		var manaBudget:float = min(transaction.manaCost, storedMana-manaCost)

		# If we don't have the mana budget, pay remaining cost as an energy transaction
		var transactionEnergyCost:float = (transaction.manaCost-manaBudget) * CONSTANTS.MANA_TO_ENERGY_RATIO
		
		attemptedEnergyCost += max(0, transactionEnergyCost)
		attemptedManaCost += max(0, manaBudget)

		if energyBankBalance < energyCost + transactionEnergyCost:
			# Can't afford the thing
			continue
		energyCost += max(0, transactionEnergyCost)
		manaCost += max(0, manaBudget)
		approvedSuccessFns.append(transaction.onSuccess)

	if energyCost == 0 and manaCost == 0:
		FlagManager.HANDLERS.WORLD.count.call_deferred("mana_cost", "cost", attemptedManaCost, true)
		FlagManager.HANDLERS.WORLD.count.call_deferred("energy_cost", "cost", attemptedEnergyCost, true)
		SignalBus.getSignal("display_mana_cost").emit.call_deferred()
		SignalBus.getSignal("display_energy_cost").emit.call_deferred()
		print("EnergyLink transaction failed: no transaction was approved")

	if energyCost > 0:
		SignalBus.getSignal("display_energy_cost").emit.call_deferred()
		FlagManager.HANDLERS.WORLD.count.call_deferred("energy_cost", "cost", energyCost, true)
		# Send the withdrawal request
		var args = {
			"key": "EnergyLink" + str(Archipelago.conn.team_id),
			"default": 0,
			"operations": [
				{"operation": "add", "value": -energyCost},
				{"operation": "max", "value": 0},
			]
		}
		Archipelago.send_command("Set", args)
		# We'll call that a success. I don't think we need the reply for this(?) But maybe it will be good if we want to guarantee an accurate bank balance
		print.call_deferred("Energy transaction succeeded: spent %s energy, predicted bank balance %s"%[energyCost, energyBankBalance-energyCost])
	
	FlagManager.setFlag("last_known_energy_bank_balance", energyBankBalance-energyCost)
	
	if manaCost > 0:
		SignalBus.getSignal("display_mana_cost").emit.call_deferred()
		FlagManager.HANDLERS.WORLD.count.call_deferred("mana_cost", "cost", manaCost, true)
		FlagManager.HANDLERS.WORLD.count.call_deferred("mana", "spent", -manaCost, true) 
		print.call_deferred("Mana spent: %s; Mana left: %s"%[manaCost, FlagManager.getTotalCountAmount("mana")])

	for fn in approvedSuccessFns:
		fn.call()

# Use unit prefixes for big numbers
static func getSimplifiedNumberString(num:float) -> String:
		var units:float = num
		var idx:int = 0
		var useScientificNotation:bool = false

		while units > 1000:
			units /= 1000
			idx += 1
			if idx >= UNIT_MULTIPLES.size():
				useScientificNotation = true
				break

		if useScientificNotation:
			return String.num_scientific(num)
		else:
			return String.num(units, 1 if idx > 0 else 0)+UNIT_MULTIPLES[idx]

static var UNIT_MULTIPLES:Array[String] = ["", "k", "M", "G", "T"]

## Get shape value of item
static func getAetherValueOfItem(itemData:CONSTANTS.ItemData) -> float:
	for shapeType:StringName in CONSTANTS.NUMBER_OF_BLOCKS_PER_SHAPE_TYPE:
		if itemData.tags.has(shapeType):
			return CONSTANTS.NUMBER_OF_BLOCKS_PER_SHAPE_TYPE[shapeType] * CONSTANTS.AETHER_PER_BLOCK
	return 0

## Lazy caller that calls a function infrequently
class LazyCaller:
	var tween:Tween
	var node:Node
	var fn:Callable
	var delay:int = 3

	## Set up a lazy caller to only call a function infrequently
	static func Make(boundNode:Node, _fn:Callable, _delay:int = 3) -> LazyCaller:
		assert(boundNode != null)
		var lc:LazyCaller = LazyCaller.new()
		lc.node = boundNode
		lc.fn = _fn
		lc.delay = _delay
		if boundNode:
			boundNode.tree_exiting.connect(lc._cleanUp, CONNECT_ONE_SHOT)
		return lc

	func lazyCall() -> void: ## Call a function with a delay between calls; Does nothing if already waiting
		if not is_instance_valid(node):
			return 
		if tween:
			# Trying to save again, so queue it
			if not tween.finished.is_connected(fn):
				tween.finished.connect(fn, CONNECT_ONE_SHOT)
			return
		# No timer is running so save and start one
		fn.call()
		tween = node.create_tween().set_pause_mode(Tween.TweenPauseMode.TWEEN_PAUSE_PROCESS)
		tween.tween_callback(fn).set_delay(delay)
		tween.finished.connect(set.bind("tween", null), CONNECT_ONE_SHOT)

	func _cleanUp() -> void:
		if tween:
			tween.kill()
			tween = null
		node = null

# Randomized save slot names
static func generateRandomSaveSlotName() -> String: ## Generate a random save slot name
	var words:Array[String] = []
	for array:PackedStringArray in [CONSTANTS.WORD_LIST.ARTICLE, CONSTANTS.WORD_LIST.ADJECTIVE, CONSTANTS.WORD_LIST.NOUN]:
		var word:String = chooseRandomFromPackedStringArray(array)
		if not word.is_empty():
			words.append(word)
	return " ".join(words)

static func chooseRandomFromPackedStringArray(array:PackedStringArray) -> String: ## Choose a random string from PackedStringArray
	if array.size():
		return array[randi_range(0, array.size() - 1)]
	return ""

# Touch state
class TouchState:
	var mousePressed:bool = false ## The mouse is pressed
	var touchPresses:Dictionary[int, bool] = {} ## Touch indexes that are pressed
	var drag:Vector2 ## Amount of distance moved unspent
	var hasDragged:bool = false: ## Has this been dragged since pressing
		set(value):
			if hasDragged == value:
				return
			hasDragged = value
			if not hasDragged:
				_lastDragAction = ""
	var _lastDragAction:StringName
	var watchedActions:Array[StringName]
	var dragStart:int
	var releaseVelocity:int

	signal drag_action_activated(action:StringName, isEcho:bool)

	static var DRAG_ACTION_DIRECTION:Dictionary[StringName, Vector2] = {
		moveLeft = Vector2.LEFT,
		moveRight = Vector2.RIGHT,
		moveDown = Vector2.DOWN,
		moveUp = Vector2.UP,
	}
	var DRAG_DEFAULT_ACTION_DOT_THRESHOLD:int = 16

	func setWatchedActions(actions:Array[StringName]) -> TouchState:
		watchedActions.append_array(actions)
		return self
	
	func reset(): ## Release presses and reset drag
		release_all()
		drag = Vector2.ZERO
		dragStart = 0

	func press_mouse() -> void: ## Make mouse pressed
		hasDragged = false
		if not isPressed():
			drag = Vector2.ZERO
			dragStart = Time.get_ticks_msec()
		mousePressed = true
	
	func release_mouse() -> void: ## Make mouse released
		mousePressed = false

	func release_all() -> void: ## Release mouse and touch
		mousePressed = false
		touchPresses.clear()

	func press_touch(index:int) -> void: ## Press touch
		hasDragged = false
		if not isPressed():
			drag = Vector2.ZERO
			dragStart = Time.get_ticks_msec()
		touchPresses[index] = true

	func release_touch(index:int) -> void: ## Release touch index
		touchPresses.erase(index)

	func isPressed() -> bool: ## Is this pressed with mouse or any touch
		if mousePressed:
			return true
		for v:bool in touchPresses.values():
			if v:
				return true
		return false
	
	func isDragged() -> bool: ## Did this get dragged?
		return hasDragged

	func getDragTime() -> float: ## Amount of time since dragging in seconds
		return float(Time.get_ticks_msec() - dragStart) / 1000.0

	func accumulateDrag(amount:Vector2) -> void: ## Add to current drag and emit drag actions
		if isPressed():
			drag += amount
			if watchedActions.size():
				var threshold:float = FlagManager.getIntFlagValue("current_zoom") * DRAG_DEFAULT_ACTION_DOT_THRESHOLD
				var breakFromActionLoop:bool = false
				for action:StringName in watchedActions:
					if DRAG_ACTION_DIRECTION.has(action):
						if drag.dot(DRAG_ACTION_DIRECTION[action]) > threshold:
							drag -= DRAG_ACTION_DIRECTION[action] * threshold
							drag *= abs(DRAG_ACTION_DIRECTION[action]) # Make drag straighter
							drag_action_activated.emit(action, action == _lastDragAction)
							_lastDragAction = action
							hasDragged = true
							break

	func getDragVelocity() -> Vector2: ## Get velocity in pixels a second
		if dragStart:
			return drag / getDragTime()
		return Vector2.ZERO