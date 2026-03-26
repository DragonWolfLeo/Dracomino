extends Node
class_name FlagHolder

signal stateflag_changed(flag)
signal stateflag_set(flag)
signal stateflag_cleared(flag)
signal stateflags_aboutToDirty(flags)
signal stateflags_dirty()
signal stateflags_reset()

### Static Variables
static var PRIORITY:Dictionary[StringName, float] = {
	OBJECT = 4,
	LEVEL = 3,
	WORLD = 2,
	MAIN = 1,
}

### Variables
@export var priority:float = 0
@export var defaultThreshold:int = 1
var stateFlags:Dictionary:
	set(value):
		stateflags_aboutToDirty.emit(stateFlags.merged(value).keys())
		stateFlags = value

		# Emit the events in all flags to trigger objects
		for flag in stateFlags:
			var isSet = false
			if _isFlagSet_basic(flag): 
				stateflag_set.emit(flag)
				stateflag_changed.emit(flag)
				isSet = true
			if stateFlags[flag] is Dictionary:
				if !isSet: stateflag_changed.emit(flag)
				for k in stateFlags[flag].keys():
					_set_counted_flag(flag,k)
		stateflags_dirty.emit()
		
var tempFlags:Dictionary
var queuedFlags:Array
var monitoring:bool = true:
	set(value):
		if stateFlags.is_empty():
			# No need to be dirty if this is just empty
			monitoring = value
		elif value != monitoring:
			stateflags_aboutToDirty.emit(stateFlags.keys())
			monitoring = value
			stateflags_dirty.emit()

var IS_FLAG_SET_OPERATORS:Array[Dictionary] = [
	{
		split = "=",
		fn = func(a, b): return isFlagEqual(a, b)
	},
]

### Virtuals ###
func _init(_priority:float = 0.0) -> void:
	name = "FlagHolder"
	priority = _priority

func _enter_tree() -> void:
	FlagManager.registerMonitoredFlagHolder(self)

### Functions ###
func resetStateFlags():
	stateFlags.clear()
	tempFlags.clear()
	queuedFlags.clear()
	stateflags_reset.emit()

func setFlag(flag:String, value = null, temp:bool = false):
	# Accept single string with space
	if value == null and " " in flag:
		var arr = flag.split(" ", false, 1)
		arr.resize(2)
		value = arr[1]
		flag = arr[0]

	assert(flag == flag.to_lower(), "Setting flag name that is not lower case: %s"%flag) # Enforce snake case

	# Default to 1
	if value == null: value = 1
	
	# Force to string
	if value is StringName: value = value as String

	# Warn operators
	if Config.debugMode:
		for o in FlagManager.OPERATOR_SYMBOLS:
			if o in flag:
				print("Warning! setFlag({flag}={value}) {o} found in flag {flag}. This won't be parsed and probably won't evaluate correctly!".format(
					{flag=flag,value=value,o=o}
				))
		
	flag = flag.to_lower()
	
	var collection = tempFlags if temp else stateFlags
	if collection.has(flag) and typeof(collection[flag]) == typeof(value) and collection[flag] == value:
		return
	stateflags_aboutToDirty.emit([flag])
	collection[flag] = value
	stateflags_dirty.emit()
	stateflag_changed.emit(flag)
	stateflag_set.emit(flag)
	
func setTempFlag(flag:String, value = null):
	setFlag(flag,value,true)
	
func queueFlag(flag:String):
	queuedFlags.append(flag)
	
func setQueuedFlags():
	while queuedFlags.size():
		setFlag(queuedFlags.pop_front())

func clearFlag(flag:String, temp:= false):
	var collection = tempFlags if temp else stateFlags
	flag = flag.to_lower()
	if !collection.has(flag):
		return
	stateflags_aboutToDirty.emit([flag])
	collection.erase(flag)
	stateflags_dirty.emit()
	stateflag_changed.emit(flag)
	stateflag_cleared.emit(flag)
	
func clearTempFlag(flag:String):
	clearFlag(flag, true)

func isFlagSet(flag:String) -> bool:
	if flag.is_empty(): return false
	# Check if there's operators present and evaluate those instead
	for opconfig:Dictionary in IS_FLAG_SET_OPERATORS:
		if opconfig.has("split") and opconfig.split in flag:
			var arr = flag.split(opconfig.split,true,1)
			if opconfig.has("fn"):
				return (opconfig.fn as Callable).callv(arr)
		elif opconfig.has("startsWith") and flag.begins_with(opconfig.startsWith):
			if opconfig.has("fn"):
				return (opconfig.fn as Callable).call(flag.trim_prefix(opconfig.startsWith))
	#
	return _isFlagSet_basic(flag.to_lower())

func _isFlagSet_basic(flag:String):
	var collections = [stateFlags, tempFlags]
	for collection in collections:
		if collection.has(flag):
			var f = collection[flag]
			if f is Dictionary: # It's a count set. We need to count if it reaches the threshold
				var total:int = 0
				for v in f.values():
					total += v
				return total >= f.threshold*2 # Multiplied by 2 because it counts the threshold itself
			else:
				return f != null # It's a primitive value. Just return it
	return false

func isFlagEqual(flag:String, value:String) -> bool:
	if flag.is_empty(): return false
	flag = flag.to_lower()

	# Warn operators
	if Config.debugMode:
		for o in FlagManager.OPERATOR_SYMBOLS:
			if o in flag:
				printerr("Warning! isFlagEqual({flag}={value}) {o} found in flag {flag}. This won't be parsed and probably won't evaluate correctly!".format(
					{flag=flag,value=value,o=o}
				))
	#
	var collections = [stateFlags, tempFlags]
	for collection in collections:
		if collection.has(flag):
			var f = collection[flag]
			if f is Dictionary: # It's a count set. We need to count if it reaches the threshold
				# Make this false if this is an expression
				printerr("Warning: {flag} is being compared to {value} when it is a count flag! This will always be false!".format({
					flag=flag,value=value,
				}))
				return false
			else:
				# Check case-insensitive because flags (including expressions) are lowercased in dialogue conditions
				return f.to_lower() == value.to_lower()
	return false
	
func getFlagValue(flag:String):
	flag = flag.to_lower()
	var f = stateFlags.get(flag)
	return (
		getTotalCountAmount(flag) if f is Dictionary
		else f
	)
	
func getIntFlagValue(flag:String) -> int:
	var result:Variant = getFlagValue(flag)
	if result is int or result is float:
		return int(result)
	return 0

func getTotalCountAmount(flag:String) -> int:
	flag = flag.to_lower()
	var f = stateFlags.get(flag)
	if f and f is Dictionary:
		# Count the total
		var total:int = 0
		for v in f.values():
			total += v
		return total - f.threshold # Subtracted because it counts the threshold itself
	return 0
	
func count(countSetId:String, key = null, weight = null, add := false):
	# Accept single string with space
	countSetId = countSetId.to_lower()
	if key == null and " " in countSetId:
		var arr = countSetId.split(" ", false, 3)
		countSetId = arr[0]
		arr.resize(4)
		if (arr[1] as String).is_valid_int(): # Number will be assumed to be weight and key will be blank
			arr.insert(1, "")
		key = arr[1]
		if (!arr[2]) or (arr[2] as String).is_valid_int():
			weight = arr[2] as int if arr[2] else 1
		else:
			printerr("Error! Weight must be a number for command: count {countSetId} {key} {weight}".format({
				countSetId = countSetId,
				key = key,
				weight = arr[2],
			}))
			return
		add = arr[3] == "add"
		if arr[3] and !add:
			print("Warning! Final parameter must literally be \"add\" to work for command: count {countSetId} {key} {weight} {add}".format({
				countSetId = countSetId,
				key = key,
				weight = weight,
				add = arr[3],
			}))
	
	# Defaults
	if weight == null: weight = 1 as int
	if key == null: key = ""
	
	# Check if the set exists
	if !stateFlags.has(countSetId):
		stateFlags[countSetId] = {threshold = defaultThreshold}
	var countSet = stateFlags[countSetId]
	if countSet is not Dictionary:
		printerr("Error! Count is conflicting with flag ", countSetId)
		return
	
	# Set the weight
	var wasSet:bool = _isFlagSet_basic(countSetId)
	stateflags_aboutToDirty.emit([countSetId])
	if countSet.has(key) and add:
		countSet[key] += weight
	else:
		countSet[key] = weight
		
	# Add to tempFlags for condition testing
	_set_counted_flag(countSetId, key)
	stateflags_dirty.emit()
		
	# Emit events
	stateflag_changed.emit(countSetId)
	var isSetNow = _isFlagSet_basic(countSetId)
	if not wasSet and isSetNow:
		stateflag_set.emit(countSetId)
	elif wasSet and not isSetNow:
		stateflag_cleared.emit(countSetId)
		
func _set_counted_flag(countSetId:String, key:String):
	if key == "threshold": return
	var countedFlag = "counted_"+countSetId+"_"+key
	if !stateFlags.has(countSetId):
		clearTempFlag(countedFlag)
	elif stateFlags[countSetId][key] > 0:
		setTempFlag(countedFlag)
	else:
		clearTempFlag(countedFlag)
	
