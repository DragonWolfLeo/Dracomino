extends Node

var mode:Node
var ui:Node
var isLoaded:bool = false # TODO: Move this to mode

signal game_loaded()

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
	loadMainScene.call_deferred()

func loadMainScene():
	get_tree().change_scene_to_file("res://singleton/main.tscn") # Overwrite the previous version's scene
	changeMode(load("res://mode/main.tscn"))

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

	# Fix save data from old versions
	UserData.upgradeDataToCurrentVersion(data)
	reset()
	isLoaded = true
	game_loaded.emit()
	
	
func newGame():
	var packedScene = load("res://mode/main.tscn")
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
