extends Node

signal setting_changed(setting:StringName)

@onready var versionNum:String = getVersionNum()
var versionCompatible:String = "0.0.0"
var debugMode:bool:
	set(value):
		changeSetting("debug", false, false)
	get():
		return getSetting("debug", false)
var showHints := true
@onready var isWeb:bool = OS.get_name() == "Web"
var SAVEFILEPATH = "user://auto.save"
var CONFIGPATH = "user://config.json"
const DEFAULT_SETTINGS:Dictionary[StringName, Variant] = {
	# Debug
	debug = false,
	# Audio
	volume = 80.0,
	volume_music = 100.0,
	volume_sfx = 100.0,
	volume_voice = 100.0,
	# Game
	auto_scaling = true,
	gravity = 1.0,
	lockDelay = 1.0,
	softDrop_speed = 1.0,
	horizontal_speed = 1.0,
	softDrop_repeatDelay = 1.0,
	horizontal_repeatDelay = 1.0,
	fishResisting = true,
	allowUnfocusedInputs = false,
	showAnnouncements = true,
	# Save index
	previousSaveFile = 0,
	autosave = true,
}
var settings:Dictionary[StringName, Variant] = DEFAULT_SETTINGS.duplicate()
## Features that will satisfy requirements in slot data
var FEATURES:Array[StringName] = []
## Features that will force a seed to be invalid if a requirement
var DISABLED_FEATURES:Array[StringName] = [
	"story",
]
var VERSION_UPGRADES:Dictionary[StringName, Callable] = {}
var lazySaver:DracominoUtil.LazyCaller = DracominoUtil.LazyCaller.Make(self, saveConfig, 3)

func _ready():
	loadConfig()
	SignalBus.registerSignalDistributor(setting_changed, "setting_changed")
		
func loadConfig():
	var path = CONFIGPATH
	if !FileAccess.file_exists(path): return
	
	var data:Dictionary = UserData.loadDataFromFile(path)
	if data.get("error"):
		printerr("Error loading config file (Error %s"%data.get("error"))
		data = {}
	UserData.upgradeDataToCurrentVersion(data, VERSION_UPGRADES)
	import(data)
	
	SoundManager.setVolume("Master", getSetting("volume", 100.0))
	SoundManager.setVolume("Music", getSetting("volume_music", 100.0))
	SoundManager.setVolume("Sfx", getSetting("volume_sfx", 100.0))
	SoundManager.setVolume("Voice", getSetting("volume_voice", 100.0))
	
func saveConfig():
	UserData.saveDataToFile(export(), CONFIGPATH)

func exportVersion() -> Dictionary:
	return {
		versionNum = versionNum,
		versionCompatible = versionCompatible,
	}

func export() -> Dictionary:
	var ret: = {}
	ret.merge(settings)
	ret.merge(exportVersion(), true)
	return ret

func import(data:Dictionary):
	settings.merge(data, true)

func changeSetting(key:StringName, value:Variant, saveAfterwards:bool = true) -> void:
	var current:Variant = settings.get(key)
	if current != value:
		settings[key] = value
		setting_changed.emit(key)
		if saveAfterwards:
			lazySaver.lazyCall()

func getSetting(key:StringName, fallback:Variant = null) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key, fallback))

func getDefaultSetting(key:StringName, fallback:Variant = null) -> Variant:
	return DEFAULT_SETTINGS.get(key, fallback)

func getVersionNum(getFullVersionInfo:bool = false) -> String: ## Get version number string from the top of the changelog
	var changelog:String = load("res://changelog.txt").text
	var regex := RegEx.create_from_string(
		"(\\S| )+" if getFullVersionInfo # Get version number and date/patch
		else "\\S(\\.\\S)+" # Get just the version number
	)
	var rm:RegExMatch = regex.search(changelog) 
	if rm and rm.strings.size():
		return rm.strings[0]
	return ""
