extends Node

var SAVE_INDEX_PATH:String = "user://saveindex.json"
var DRACOMINO_SAVE_DIRECTORY:String = "user://dracomino_saves/"

var saveIndex:Dictionary[StringName, Dictionary] = {}

var saveIndexSaver:DracominoUtil.LazyCaller = DracominoUtil.LazyCaller.Make(self, saveSaveIndex, 5)

class DATATYPE:
	const DRACOMINO_DATA:String = "dracominodata"

# === Virtuals ===
func _ready():
	loadSaveIndex()
	buildMissingSaveIndex()

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

func deleteFile(path:String) -> Error: ## Delete a file
	return DirAccess.remove_absolute(path)

func initFileData(data:Dictionary, dataType:String) -> void: ## Add data type and version
	data["dataType"] = dataType
	data["timestamp"] = Time.get_unix_time_from_system()
	data.merge(Config.exportVersion(), true)

# --- Dracomino saving functions ---
func saveDracominoDataToFile(data:Dictionary, fileNum:int, printErrorFn:Callable = _noop) -> Error:
	initFileData(data, DATATYPE.DRACOMINO_DATA)
	var source:String = "UserData.saveDracominoDataToFile"
	if fileNum < 0:
		_callPrintErrorCallable(printErrorFn, "Cannot save game - File number must be non-negative", source)
		return ERR_PARAMETER_RANGE_ERROR
	var path:String = _makeDracominoSaveFilePath(fileNum)
	var err:Error = saveDataToFile(data, path)
	var seedData:Dictionary = data.get("seedState")
	if seedData is Dictionary:
		if seedData.get("isAP", false):
			Archipelago.save_manager.write_save(fileNum)
		else:
			Archipelago.save_manager.delete_save(fileNum)
	if err: _callPrintErrorCallable(printErrorFn, "Error saving (Error %s)"%err, source)
	# Update index
	var saveInfo:Dictionary = makeSaveInfoDict(data, "File %s"%fileNum)
	saveIndex[str(fileNum)] = saveInfo
	saveSaveIndex()
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
		if not isDataCompatibleVersion(data):
			_callPrintErrorCallable(printErrorFn, "Load error - incompatible version; Requires version %s"%data.get("versionCompatible"), source)
			data["error"] = ERR_INVALID_DATA
			return data
		upgradeDataToCurrentVersion(data, DRACOMINO_DATA_VERSION_UPGRADES)
		
		var seedData:Dictionary = data.get("seedState")
		if seedData is Dictionary:
			if seedData.get("isAP", false):
				if not Archipelago.conn:
					Archipelago.save_manager.read_save(fileNum)
				else:
					Archipelago.save_manager.open_save_ind = fileNum
		Archipelago.aplock = null
		return data

	_callPrintErrorCallable(printErrorFn, "Cannot load - File %s does not exist."%fileNum, source)
	return {error=ERR_FILE_NOT_FOUND}

func deleteDracominoDataFile(fileNum:int) -> Error:
	var path:String = _makeDracominoSaveFilePath(fileNum)
	var err:Error = deleteFile(path)
	Archipelago.save_manager.delete_save(fileNum)
	saveIndex.erase(str(fileNum))
	saveSaveIndex()
	return err

func _makeDracominoSaveFilePath(fileNum) -> String:
	return "{dir}/{fileNum}.save".format({dir = DRACOMINO_SAVE_DIRECTORY, fileNum = fileNum})

var DRACOMINO_DATA_VERSION_UPGRADES:Dictionary[StringName, Callable] = {}

# --- Save index functions ---
func loadSaveIndex() -> void: ## Loads the save index from file
	var path:String = SAVE_INDEX_PATH
	# Load current file
	if FileAccess.file_exists(path):
		# Load save index from file
		var data:Dictionary = loadDataFromFile(path)
		if data.get("error"):
			printerr("Error loading save index file (Error %s"%data.get("error"))
			data = {}
		for k:Variant in data.keys():
			var indexData:Variant = data[k]
			if indexData is Dictionary:
				saveIndex[k] = indexData

func saveSaveIndex() -> void: ## Saves the save index to file
	UserData.saveDataToFile(saveIndex, SAVE_INDEX_PATH)

func buildMissingSaveIndex() -> void: ## Search save directory and fill missing save indexes
	var dir:String = DRACOMINO_SAVE_DIRECTORY
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files:PackedStringArray = DirAccess.get_files_at(dir)
	var saveIndexUpdated:bool = false
	for fileName:String in files:
		var fileNum:String = fileName.get_basename()
		if fileNum.is_valid_int() and not saveIndex.has(fileNum):
			var path:String = _makeDracominoSaveFilePath(int(fileNum))
			var data = loadDataFromFile(path)
			saveIndex[fileNum] = makeSaveInfoDict(data, "File %s"%fileNum)
			saveIndexUpdated = true
	if saveIndexUpdated:
		saveSaveIndex()

func makeSaveInfoDict(data:Dictionary, saveSlotName:StringName) -> Dictionary: ## Makes the data for a save index entry
	var info:Dictionary = {}
	if data.get("error"):
		return {error = 1}
	var numChecked:int = 0
	var totalLocations:int = 0
	var requirements:Array = []
	var seedStateData:Dictionary = {}
	var slotData:Dictionary = {}
	if data.get("checkedLocations") is Array:
		numChecked = (data["checkedLocations"] as Array).size()
		if data.get("missingLocations") is Array:
			totalLocations = numChecked + (data["missingLocations"] as Array).size()
	if data.get("requirements") is Array:
		requirements = data["requirements"]
	if data.get("seedState") is Dictionary:
		seedStateData = data["seedState"]
		if seedStateData.get("slotData") is Dictionary:
			slotData = seedStateData["slotData"]
	var mainChapterId:StringName = str(data.get("mainChapterId", ""))
	var mainChapterName:StringName = mainChapterId
	var chapter:Story.Chapter = Story.CHAPTERS.get(mainChapterId)
	if chapter is Story.Chapter:
		mainChapterName = chapter.prettyName
	info = {
		timestamp = float(data.get("timestamp", 0)),
		saveSlotName = str(seedStateData["slotData"].get("save_slot_name", saveSlotName)),
		generatorVersion = str(slotData.get("generator_version", "")),
		slotContextHash = str(data.get("slotContextHash", "")),
		isAP = int(seedStateData.get("isAP", 0)),
		victory = int(data.get("victory", 0)),
		numChecked = numChecked,
		totalLocations = totalLocations,
		gameType = str(data.get("gameType", "")),
		mainChapterName = mainChapterName,
		requirements = requirements,
		icon = "",
	}
	return info

## Functions to upgrade old save data
var VERSION_UPGRADES:Dictionary[StringName, Callable] = {}
## Upgrades old save data to current version by calling functions in `VERSION_UPGRADES`
func upgradeDataToCurrentVersion(data:Dictionary, versionUpgrades:Dictionary[StringName, Callable] = VERSION_UPGRADES) -> void:
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