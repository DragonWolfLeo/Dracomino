extends Node

var DRACOMINO_SAVE_DIRECTORY:String = "user://dracomino_saves/"


# === Functions ===
# --- General saving functions ---
func saveDataToFile(data:Dictionary, path:String) -> Error: ## Save a dictionary to a file
	if data.is_empty(): return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file: return ERR_FILE_CANT_OPEN
	var json_string := JSON.stringify(data, "\t")
	file.store_line(json_string)
	return OK
	
func loadDataFromFile(path:String) -> Dictionary: ## Load a file and return a dictionary. Returns dictionary with `error` key when there's an error.
	if !FileAccess.file_exists(path): return {error=ERR_FILE_NOT_FOUND}
	
	# Load the JSON
	var file := FileAccess.open(path, FileAccess.READ)
	var json_string := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " in ", path, " at line ", json.get_error_line())
		return {error=ERR_PARSE_ERROR}
	return json.get_data()

# --- Dracomino saving functions ---
func saveDracominoDataToFile(data:Dictionary, fileNum:int, printErrorFn:Callable = _noop) -> Error:
	var source:String = "UserData.saveDracominoDataToFile"
	if fileNum < 0:
		_callPrintErrorCallable(printErrorFn, "Cannot save game - File number must be non-negative", source)
		return ERR_PARAMETER_RANGE_ERROR
	var path:String = _makeDracominoSaveFilePath(fileNum)
	var err:Error = saveDataToFile(data, path)
	if data.get("isAP", false):
		Archipelago.save_manager.write_save(fileNum)
	else:
		Archipelago.save_manager.delete_save(fileNum)
	if err: _callPrintErrorCallable(printErrorFn, "Error saving (Error %s)"%err, source)
	return err

func loadDracominoDataFromFile(fileNum:int, printErrorFn:Callable = _noop) -> Dictionary:
	var source:String = "UserData.loadDracominoDataFromFile"
	if fileNum < 0:
		_callPrintErrorCallable(printErrorFn, "Cannot load game - File number must be non-negative", source)
		return {error=ERR_PARAMETER_RANGE_ERROR}
	var path:String = _makeDracominoSaveFilePath(fileNum)
	if doesFileExist(path):
		var data:Dictionary = UserData.loadDataFromFile(path)
		if data.get("error"):
			_callPrintErrorCallable(printErrorFn, "Cannot load - Error loading file (Error %s)."%data.get("error"), source)
			return data
		if data.get("isAP", false):
			if not Archipelago.conn:
				Archipelago.save_manager.read_save(fileNum)
			else:
				Archipelago.save_manager.open_save_ind = fileNum
		Archipelago.aplock = null
		return data

	_callPrintErrorCallable(printErrorFn, "Cannot load - File %s does not exist."%fileNum, source)
	return {error=ERR_FILE_NOT_FOUND}

func _makeDracominoSaveFilePath(fileNum) -> String:
	return "{dir}/{fileNum}.save".format({dir = DRACOMINO_SAVE_DIRECTORY, fileNum = fileNum})

## Functions to upgrade old save data
var VERSION_UPGRADES:Dictionary[StringName, Callable] = {}
## Upgrades old save data to current version by calling functions in `VERSION_UPGRADES`
func upgradeDataToCurrentVersion(data:Dictionary, versionUpgrades:Dictionary[StringName, Callable] = VERSION_UPGRADES):
	_convertFloatsToInt(data.get("stateFlags", {}))
	if !data.has("versionNum"): return
	var datahash := data.hash()
	
	var upgrades:Array[Dictionary] = []
	for versionNum:StringName in versionUpgrades:
		upgrades.append({versionNum = versionNum, fn = versionUpgrades[versionNum]})
		
	upgrades.sort_custom(func(a,b): return versionIsOlderThan(a.versionNum,b.versionNum))	
	
	for upgrade:Dictionary in upgrades:
		if versionIsOlderThan(data.versionNum, upgrade.versionNum):
			upgrade.fn.call(data)
	
	if datahash != data.hash():
		print("Updated save data from Version ", data.versionNum)
		

func versionIsOlderThan(numA:String, numB:String) -> bool: ## Compares version number strings
	if numA == numB: return false
	var customSplit:Callable = func(string:String)-> Array:
		var ret: = []
		var parse: = ""
		var isNum: = false
		for c:String in string:
			if c == ".":
				ret.append(parse)
				parse = ""
			elif c.is_valid_int() and !isNum:
				if parse.length():
					ret.append(parse)
					parse = ""
				isNum = true
			elif !c.is_valid_int() and isNum:
				if parse.length():
					ret.append(parse)
					parse = ""
				isNum = false
			parse += c
		ret.append(parse)
		return ret
		
	var arrA:Array = customSplit.call(numA)
	var arrB:Array = customSplit.call(numB)
	
	var a:String = ""
	var b:String = ""
	while(a == b):
		if a == null:
			printerr("Error comparing version numbers ", numA," and ", numB)
			return false
		a = arrA.pop_front()
		b = arrB.pop_front()
	
	return (
		true if a == null else 
		false if b == null else
		a < b if (!a.is_valid_int() or !b.is_valid_int()) else
		a.to_int() < b.to_int()
	)

func doesFileExist(path:String = Config.SAVEFILEPATH) -> bool: ## Checks if a file exists
	return FileAccess.file_exists(path)
	
func isDataCompatibleVersion(data:Dictionary) -> bool: ## Check if a data dictionary is compatible with current version
	var minVersion:String = str(data.get("versionCompatible", data.get("versionNum", "")))
	if !minVersion.length(): return true
	return not versionIsOlderThan(Config.versionNum, minVersion)

# === Private functions ===
func _convertFloatsToInt(data:={}) -> void:
	for k:Variant in data.keys():
		if data[k] is float:
			data[k] = int(data[k])
		elif data[k] is Dictionary:
			_convertFloatsToInt(data[k])

func _callPrintErrorCallable(fn:Callable, message:String, source:String = "") -> void: ## Print an error message while calling error print callable
	if fn and fn.get_argument_count() > 0:
		fn.call(message)
	printerr((source + " error: " if source else "") + message)

func _noop():
	pass