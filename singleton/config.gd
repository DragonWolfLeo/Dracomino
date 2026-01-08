extends Node

signal setting_changed(setting:StringName)

@onready var versionNum:String = getVersionNum()
var versionCompatible:String = "0.0.0"
var debugMode := false
var showHints := true
@onready var isWeb:bool = OS.get_name() == "Web"
var SAVEFILEPATH = "user://auto.save"
var CONFIGPATH = "user://config.json"
const DEFAULT_SETTINGS:Dictionary[StringName, Variant] = {
	# Audio
	volume = 80.0,
	volume_music = 100.0,
	volume_sfx = 100.0,
	# Game
	gravity = 1.0,
}
var settings:Dictionary[StringName, Variant] = DEFAULT_SETTINGS.duplicate()
var VERSION_UPGRADES:Dictionary[String, Callable] = {
	"0.2.2.1": func(data:Dictionary):
		if data.get("gravity") is float: # Try to preserve current gravity settings
			data["gravity"] = snapped(data["gravity"]*0.8, 0.1) as float
}

func _ready():
	loadConfig()
	SignalBus.registerSignalDistributor(setting_changed, "setting_changed")
		
func loadConfig():
	var path = CONFIGPATH
	if !FileAccess.file_exists(path): return
	
	var data:Dictionary = UserData.loadDataFromFile(path)
	UserData.upgradeDataToCurrentVersion(data, VERSION_UPGRADES)
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
	ret.merge(exportVersion(), true)
	return ret

func import(data:Dictionary):
	if data.has("debug"): debugMode = data.debug
	settings.merge(data, true)

func changeSetting(key:StringName, value:Variant, saveAfterwards:bool = true) -> void:
	var current:Variant = settings.get(key)
	if current != value:
		settings[key] = value
		setting_changed.emit(key)
		if saveAfterwards:
			lazySaveConfig()

func getSetting(key:StringName, fallback:Variant = null) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key, fallback))

func getDefaultSetting(key:StringName, fallback:Variant = null) -> Variant:
	return DEFAULT_SETTINGS.get(key, fallback)

func getVersionNum():
	var changelog:String = load("res://changelog.txt").text
	var regex := RegEx.create_from_string("\\S(\\.\\S)+") # Should get the version number
	var rm := regex.search(changelog) 
	var version = ""
	if rm and rm.strings.size(): version = rm.strings[0]
	return version