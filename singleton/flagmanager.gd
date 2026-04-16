extends Node

signal stateflag_changed(flag)
signal stateflag_set(flag)
signal stateflag_cleared(flag)
signal stateflags_reset()

class SpecialFlagHolderHandler:
	var flagHolder:FlagHolder:
		set(object):
			if object != flagHolder:
				if flagHolder != null and flagHolder.tree_exiting.is_connected(_clearFlagHolder):
					flagHolder.tree_exiting.disconnect(_clearFlagHolder)
				flagHolder = object
				if flagHolder != null:
					flagHolder.tree_exiting.connect(_clearFlagHolder)

	func setAsFlagHolder(object:FlagHolder):
		# Use this function for setting the handler
		flagHolder = object

	func _clearFlagHolder():
		flagHolder = null

	func setFlag(flag:String, value = null, temp:bool = false):
		if flagHolder != null:
			flagHolder.setFlag(flag, value, temp)

	func clearFlag(flag:String, temp:= false):
		if flagHolder != null:
			flagHolder.clearFlag(flag, temp)

	func count(countSetId:String, key = null, weight = null, add := false):
		if flagHolder != null:
			flagHolder.count(countSetId, key, weight, add)

var HANDLERS:Dictionary[StringName, SpecialFlagHolderHandler] = {
	MAIN = SpecialFlagHolderHandler.new(),
	WORLD = SpecialFlagHolderHandler.new(),
	LEVEL = SpecialFlagHolderHandler.new(),
}

var flagHolders:Array = []
var stateFlags:Dictionary:
	get:
		if HANDLERS.MAIN.flagHolder:
			return HANDLERS.MAIN.flagHolder.stateFlags
		return {}
	set(value):
		if HANDLERS.MAIN.flagHolder:
			HANDLERS.MAIN.flagHolder.stateFlags = value
		else:
			printerr("Tried to set FlagManager.stateFlags while HANDLERS.MAIN.flagHolder is null!")

var queuedFlags:Array:
	get:
		if HANDLERS.MAIN.flagHolder:
			return HANDLERS.MAIN.flagHolder.queuedFlags
		return []
	set(value):
		if HANDLERS.MAIN.flagHolder:
			HANDLERS.MAIN.flagHolder.queuedFlags = value
		else:
			printerr("Tried to set FlagManager.queuedFlags while HANDLERS.MAIN.flagHolder is null!")

var IS_FLAG_SET_OPERATORS:Array[Dictionary] = [
	{
		split = "+",
		fn = func(a, b): return isFlagSet(a) and isFlagSet(b)
	},
	{
		split = "/",
		fn = func(a, b): return isFlagSet(a) or isFlagSet(b)
	},
	{
		startsWith = "!",
		fn = func(a:String): return not isFlagSet(a)
	},
]
var OPERATOR_SYMBOLS:Array[String] = ["=", "+", "/", "!"]

### Virtuals
func _ready() -> void:
	SignalBus.registerSignalDistributor(stateflag_set, "stateflag_set")
	SignalBus.registerSignalDistributor(stateflag_changed, "stateflag_changed")
	SignalBus.registerSignalDistributor(stateflag_cleared, "stateflag_cleared")

### Registration (Flag holders call on enter_tree) ###
func registerMonitoredFlagHolder(object: FlagHolder):
	if not flagHolders.has(object):
		flagHolders.append(object)
		object.stateflags_aboutToDirty.connect(_on_stateflags_aboutToDirty.bind(object))
		object.tree_exiting.connect(_unregisterMonitoredFlagHolder.bind(object), CONNECT_ONE_SHOT)

func _unregisterMonitoredFlagHolder(object: FlagHolder):
	object.stateflags_aboutToDirty.disconnect(_on_stateflags_aboutToDirty)
	flagHolders.erase(object)

### State flag relay functions ###
func setFlag(flag:String, value = null, temp:bool = false):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.setFlag(flag, value, temp)
	
func setTempFlag(flag:String, value = null):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.setFlag(flag, value, true)
	
func queueFlag(flag:String):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.queuedFlags.append(flag)
	
func setQueuedFlags():
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.setQueuedFlags()

func clearFlag(flag:String, temp:= false):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.clearFlag(flag, temp)
	
func clearTempFlag(flag:String):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.clearFlag(flag, true)

func isFlagSet(flag:String) -> bool:
	assert(flag == flag.to_lower(), "Checking for flag name that is not lower case: %s"%flag) # Enforce snake case
	if flag.is_empty(): return false
	
	# Check if there's operators present and evaluate those instead
	for opconfig:Dictionary in IS_FLAG_SET_OPERATORS:
		if opconfig.has("split") and opconfig.split in flag:
			var arr = flag.split(opconfig.split, true, 1)
			if opconfig.has("fn"): return (opconfig.fn as Callable).callv(arr)
		elif opconfig.has("startsWith") and flag.begins_with(opconfig.startsWith):
			if opconfig.has("fn"): return (opconfig.fn as Callable).call(flag.trim_prefix(opconfig.startsWith))

	return _isFlagSet_basic(flag)

func _isFlagSet_basic(flag:String) -> bool:
	# Check if flag is set anywhere
	for fh in flagHolders:
		if not fh.monitoring:
			continue
		var result = fh.isFlagSet(flag)
		if result:
			return true

	return false
	
func getFlagValue(flag:String) -> Variant:
	var result = null
	var priority:float = 0.0
	for fh in flagHolders:
		if not fh.monitoring or (result != null and fh.priority <= priority):
			continue
		var value = fh.getFlagValue(flag)
		if value != null:
			result = value
			priority = fh.priority
	return result

func getIntFlagValue(flag:String) -> int:
	var result:Variant = getFlagValue(flag)
	if result is int or result is float:
		return int(result)
	return 0

func getTotalCountAmount(flag:String) -> int:
	var amount:int = 0
	for fh in flagHolders:
		if not fh.monitoring:
			continue
		amount += fh.getTotalCountAmount(flag)

	return amount
	
func count(countSetId:String, key = null, weight = null, add := false):
	if HANDLERS.MAIN.flagHolder != null:
		HANDLERS.MAIN.flagHolder.count(countSetId, key, weight, add)

### Events
func _on_stateflags_aboutToDirty(flags, source:FlagHolder):
	var flagWasSet = {}
	var flagPrevValue = {}
	var flagTotalCount = {}
	# Store previous state of to-become-dirty flags
	for flag in flags:
		flagWasSet[flag] = _isFlagSet_basic(flag)
		flagPrevValue[flag] = getFlagValue(flag)
		flagTotalCount[flag] = getTotalCountAmount(flag)
	await source.stateflags_dirty
	# Emit registeredSignals for what actually happened
	for flag in flags:
		if _isFlagSet_basic(flag):
			if !flagWasSet[flag]:
				stateflag_set.emit(flag)
		elif flagWasSet[flag]:
			stateflag_cleared.emit(flag)
		
		var v1 = getFlagValue(flag)
		var v2 = flagPrevValue[flag]
		if (
			typeof(v1) != typeof(v2)
			or (v1 != v2)
			or (flagTotalCount[flag] != getTotalCountAmount(flag))
		):
			stateflag_changed.emit(flag)
