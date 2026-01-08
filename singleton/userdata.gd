extends Node

func saveDataToFile(data:Dictionary, path:String)->Error:
	if data.is_empty(): return ERR_UNCONFIGURED
	var file := FileAccess.open(path, FileAccess.WRITE)
	var json_string = JSON.stringify(data, "\t")
	file.store_line(json_string)
	return OK
	
func loadDataFromFile(path)->Dictionary:
	if !FileAccess.file_exists(path): return {error=ERR_FILE_NOT_FOUND}
	
	# Load the JSON
	var file := FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	var json := JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return {error=ERR_PARSE_ERROR}
	return json.get_data()

var VERSION_UPGRADES:Dictionary[String, Callable] = {}

func _convertFloatsToInt(data:={}):
	for k:String in data:
		if data[k] is float:
			data[k] = int(data[k])
		elif data[k] is Dictionary:
			_convertFloatsToInt(data[k])
	
func upgradeDataToCurrentVersion(data:Dictionary, versionUpgrades:Dictionary[String, Callable] = VERSION_UPGRADES):
	_convertFloatsToInt(data.get("stateFlags", {}))
	if !data.has("versionNum"): return
	var datahash = data.hash()
	
	var upgrades = []
	for versionNum in versionUpgrades:
		upgrades.append({versionNum = versionNum, fn = versionUpgrades[versionNum]})
		
	upgrades.sort_custom(func(a,b): return versionIsOlderThan(a.versionNum,b.versionNum))	
	
	for upgrade in upgrades:
		if versionIsOlderThan(data.versionNum, upgrade.versionNum):
			upgrade.fn.call(data)
	
	if datahash != data.hash():
		print("Updated save data from Version ", data.versionNum)
		

func versionIsOlderThan(numA:String, numB:String)->bool:
	if numA == numB: return false
	var customSplit = func(string:String)->Array:
		var ret: = []
		var parse: = ""
		var isNum: = false
		for i in string:
			if i == ".":
				ret.append(parse)
				parse = ""
			elif i.is_valid_int() and !isNum:
				if parse.length():
					ret.append(parse)
					parse = ""
				isNum = true
			elif !i.is_valid_int() and isNum:
				if parse.length():
					ret.append(parse)
					parse = ""
				isNum = false
			parse += i
		ret.append(parse)
		return ret
		
	var arrA:Array = customSplit.call(numA)
	var arrB:Array = customSplit.call(numB)
	
	var a = ""
	var b = ""
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

func doesSaveFileExist():
	return FileAccess.file_exists(Config.SAVEFILEPATH)
	
func isNewVersion(data:Dictionary) -> bool:
	var ver = data.get("versionCompatible", data.get("versionNum", ""))
	if !ver.length(): return false
	return Config.versionNum < ver
