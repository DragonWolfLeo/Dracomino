extends Node

var mode:Node
var ui:Node
var isLoaded:bool = false # TODO: Move this to mode

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
	add_child(mode)

func _ready():
	_setUpSingletonSignals.call_deferred()
	loadMainScene.call_deferred()

func _setUpSingletonSignals() -> void: # Set up signals to singleton objects
	# Set up trap link signal
	SignalBus.getSignal("stateflag_set", "trap_link").connect(Archipelago.set_traplink.bind(true))
	SignalBus.getSignal("stateflag_cleared", "trap_link").connect(Archipelago.set_traplink.bind(false))

	# Make the EnergyLink tag appear when energy link is enabled
	SignalBus.getSignal("stateflag_set", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", true))
	SignalBus.getSignal("stateflag_cleared", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", false))

	SignalBus.getSignal("saveGame").connect(DracominoCommandManager.activateCommand.bind("SAVE"))
	SignalBus.getSignal("loadGame").connect(DracominoCommandManager.activateCommand.bind("LOAD"))

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

func loadTitle():
	var packedScene = load("res://mode/titlescreen.tscn")
	changeMode(packedScene)
