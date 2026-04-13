class_name DracominoUtil # TODO: Rename to Util when cleaning up GodotAP
extends Node

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

class DeathContext:
	var category:String
	var itemContext:DracominoHandler.StateItem
	var contextTags:Array[String]
	var formatValues:Dictionary = {}
	func _init(_category:String, _itemContext:DracominoHandler.StateItem = null) -> void:
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
		FlagManager.HANDLERS.WORLD.setFlag("mana_cost", attemptedManaCost)
		FlagManager.HANDLERS.WORLD.setFlag("energy_cost", attemptedEnergyCost)
		SignalBus.getSignal("display_mana_cost").emit()
		SignalBus.getSignal("display_energy_cost").emit()
		print("EnergyLink transaction failed: no transaction was approved")

	if energyCost > 0:
		SignalBus.getSignal("display_energy_cost").emit()
		FlagManager.HANDLERS.WORLD.setFlag("energy_cost", energyCost)
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
		print("Energy transaction succeeded: spent %s energy, predicted bank balance %s"%[energyCost, energyBankBalance-energyCost])
	
	FlagManager.setFlag("last_known_energy_bank_balance", energyBankBalance-energyCost)
	
	if manaCost > 0:
		SignalBus.getSignal("display_mana_cost").emit()
		FlagManager.HANDLERS.WORLD.setFlag("mana_cost", manaCost)
		FlagManager.HANDLERS.WORLD.count("mana", "spent", -manaCost, true) 
		print("Mana spent: %s; Mana left: %s"%[manaCost, FlagManager.getTotalCountAmount("mana")])

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