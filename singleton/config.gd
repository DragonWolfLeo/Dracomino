extends Node

@onready var versionNum:String = getVersionNum()
var versionCompatible:String = "0.0.0"
var debugMode := false
var showHints := true
var volume:= 80.0
var volume_music := 100
var volume_sfx := 100
@onready var isWeb:bool = OS.get_name() == "Web"
var SAVEFILEPATH = "user://auto.save"
var CONFIGPATH = "user://config.json"

func _ready():
	if !OS.is_debug_build():
		debugMode = false # Auto set debug mode in case I forget
	loadConfig()
		
func loadConfig():
	var path = CONFIGPATH
	if !FileAccess.file_exists(path): return
	
	var data = UserData.loadDataFromFile(path)
	import(data)
	
func saveConfig():
	UserData.saveDataToFile(export(), CONFIGPATH)

func exportVersion()->Dictionary:
	return {
		versionNum = versionNum,
		versionCompatible = versionCompatible,
	}
func export()->Dictionary:
	var ret = {
		debug = debugMode,
		volume = volume,
		volume_music = volume_music,
		volume_sfx = volume_sfx,
	}
	ret.merge(exportVersion())
	return ret
	
func import(data:Dictionary):
	if data.has("debug"): debugMode = data.debug
	if data.has("volume"): volume = data.volume
	if data.has("volume_music"): volume_music = data.volume_music
	if data.has("volume_sfx"): volume_sfx = data.volume_sfx

func getVersionNum():
	var changelog:String = load("res://changelog.txt").text
	var regex := RegEx.create_from_string("\\S(\\.\\S)+") # Should get the version number
	var rm := regex.search(changelog) 
	var version = ""
	if rm and rm.strings.size(): version = rm.strings[0]
	return version
