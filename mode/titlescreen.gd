extends Control

#signal game_started()
@onready var versionLabel = $MainScreen/VersionLabel
@onready var SUBMENU = {
	MAIN = $MainScreen,
}

var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")

# === Virtuals ===
func _ready():
	find_child("Button_Exit").visible = !Config.isWeb
	showSubmenu()
	
	updateVersionInfo()		
	(find_child("Button_Continue") as Button).disabled = !UserData.doesSaveFileExist()

func _gui_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_accept") 
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
	):
		var nextValidFocus:Control = find_next_valid_focus()
		if nextValidFocus:
			nextValidFocus.grab_focus()
			accept_event()

# === Functions ===
func updateVersionInfo() -> void: ## Fill in version info on bottom of title screen
	var versionInfo:String = Config.getVersionNum(true)
	versionLabel.text = versionLabel.text.format({
		versionNum=versionInfo,
		patchInfo = "",
	})

func showSubmenu(menu:Control = null) -> void:
	# Hide all menus
	for v in SUBMENU.values():
		v.hide()
	
	# Show the one we want
	if !menu: menu = SUBMENU.get("MAIN")
	if menu: menu.show()
	
	grab_focus()
	
# === Events ===
func _on_ButtonNew_pressed():
	if UserData.doesSaveFileExist():
		pass # TODO
	else:
		Game.newGame()

func _on_ButtonExit_pressed():
	get_tree().quit()

func _on_ButtonChangeLog_pressed():
	var _changelogWindow:Window = CHANGELOG_WINDOW_SCENE.instantiate() as Window
	_changelogWindow.popup_exclusive_centered(self)

func _on_ButtonContinue_pressed():
	if not FileAccess.file_exists(Config.SAVEFILEPATH):
		print("There's no file to load!!!")
		return # Error! We don't have a save to load.	
	
	var data = UserData.loadDataFromFile(Config.SAVEFILEPATH)
	
	# TODO: Check if version compatible
	
	Game.loadGameData(data)
