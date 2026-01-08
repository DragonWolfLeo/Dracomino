extends Node

signal setting_changed(setting:StringName)

@onready var versionNum:String = getVersionNum()
var versionCompatible:String = "0.0.0"
var debugMode := false
var showHints := true
@onready var isWeb:bool = OS.get_name() == "Web"
var SAVEFILEPATH = "user://auto.save"
var CONFIGPATH = "user://config.json"
var settings:Dictionary = {
	# Set defaults
	# Audio
	volume = 80.0,
	volume_music = 100.0,
	volume_sfx = 100.0,
	# Game
	gravity = 1.5,
}

func _ready():
	loadConfig()
	SignalBus.registerSignalDistributor(setting_changed, "setting_changed")
		
func loadConfig():
	var path = CONFIGPATH
	if !FileAccess.file_exists(path): return
	
	var data = UserData.loadDataFromFile(path)
	import(data)
	
func saveConfig():
	UserData.saveDataToFile(export(), CONFIGPATH)

var _saveTimer:SceneTreeTimer
func lazySaveConfig(): ## A lazy, less frequent save function
	if _saveTimer:
		# Trying to save again, so queue it
		if not _saveTimer.timeout.is_connected(saveConfig):
			_saveTimer.timeout.connect(saveConfig, CONNECT_ONE_SHOT)
		return
	# No timer is running so save and start one
	saveConfig()
	_saveTimer = get_tree().create_timer(3)
	_saveTimer.timeout.connect(set.bind("_saveTimer", null), CONNECT_ONE_SHOT)

func exportVersion() -> Dictionary:
	return {
		versionNum = versionNum,
		versionCompatible = versionCompatible,
	}

func export() -> Dictionary:
	var ret: = {
		debug = debugMode,
	}
	ret.merge(settings)
	ret.merge(exportVersion())
	return ret

func import(data:Dictionary):
	if data.has("debug"): debugMode = data.debug
	settings.merge(data, true)

func changeSetting(key:StringName, value:Variant, saveAfterwards:bool = true) -> void:
	var current:Variant = settings.get(value)
	if current != value:
		settings[key] = value
		setting_changed.emit(key)
		if saveAfterwards:
			lazySaveConfig()

func getSetting(key:StringName, default:Variant = null) -> Variant:
	return settings.get(key, default)

func getVersionNum():
	var changelog:String = load("res://changelog.txt").text
	var regex := RegEx.create_from_string("\\S(\\.\\S)+") # Should get the version number
	var rm := regex.search(changelog) 
	var version = ""
	if rm and rm.strings.size(): version = rm.strings[0]
	return version
