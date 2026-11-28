extends MarginContainer

var mode:Node
var ui:Node
var isLoaded:bool = false # TODO: Move this to mode

var targetSaveFileNum:int = 0
var targetSaveSlotName:String = "File 0"

@onready var gameViewport:SubViewport = %GameViewport

var _virtualKeyboardHeight:int = 0

signal game_loaded()
signal game_data_loaded(data:Dictionary)

func changeMode(packedScene:PackedScene):
	if packedScene == null:
		printerr("Game.changeMode: packedScene is null!")
		return
	if mode: 
		mode.queue_free()
		mode = null
		isLoaded = false
	mode = packedScene.instantiate()
	gameViewport.add_child(mode)

func _ready():
	_setUpSingletonSignals.call_deferred()
	loadMainScene.call_deferred()

func _process(_delta: float) -> void:
	if Config.isMobile and not Config.isEditor:
		# Offset the virtual
		var current:int = DisplayServer.virtual_keyboard_get_height()
		if _virtualKeyboardHeight != current:
			_virtualKeyboardHeight = current
			add_theme_constant_override("margin_bottom", _virtualKeyboardHeight)

func _setUpSingletonSignals() -> void: # Set up signals to singleton objects
	# Set up trap link signal
	SignalBus.getSignal("stateflag_set", "trap_link").connect(Archipelago.set_traplink.bind(true))
	SignalBus.getSignal("stateflag_cleared", "trap_link").connect(Archipelago.set_traplink.bind(false))

	# Make the EnergyLink tag appear when energy link is enabled
	SignalBus.getSignal("stateflag_set", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", true))
	SignalBus.getSignal("stateflag_cleared", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", false))

	# Debug touch flag
	SignalBus.getSignal("stateflag_set", "emulate_touch").connect(Input.set.bind("emulate_touch_from_mouse", true))
	SignalBus.getSignal("stateflag_cleared", "emulate_touch").connect(Input.set.bind("emulate_touch_from_mouse", false))

	# Updating dialogue lowers trap duration
	DialogueManager.dialogue_updated.connect(SignalBus.getSignal("effect_duration_down").emit.unbind(2))

	# Sync nonlocal item send setting with GodotAP
	SignalBus.getSignal("setting_changed", "showNonlocalItemSends").connect(
		func(): Archipelago.AP_HIDE_NONLOCAL_ITEMSENDS = not Config.getSetting("showNonlocalItemSends", false)
	)

func loadMainScene():
	get_tree().change_scene_to_file("res://singleton/main.tscn") # Overwrite the previous version's scene
	changeMode(load("res://mode/titlescreen.tscn"))

func reset():
	pass
	
func saveGame(data:={}, path:String = Config.SAVEFILEPATH):
	data.merge(Config.exportVersion())
	data.merge({
	})
	
	var error = UserData.saveDataToFile(data, path)
	if !error: print("Saved game")
	
func loadGameData(data:Dictionary):
	if data.has("error"):
		printerr("Error loading file")
		return

	newGame()
	isLoaded = true
	game_loaded.emit()
	game_data_loaded.emit(data)
	
func newGame():
	var packedScene = load("res://mode/gamesplit.tscn")
	if packedScene == null: return
	reset()
	changeMode(packedScene)
	isLoaded = true
	game_loaded.emit()

func waitIfNotLoaded() -> void:
	if !isLoaded:
		await game_loaded

func loadTitle() -> void: ## Return to title screen # TODO: This doesn't work correctly!
	Archipelago.force_disconnect()
	var packedScene = load("res://mode/titlescreen.tscn")
	changeMode(packedScene)
