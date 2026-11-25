extends Control

#signal game_started()
@onready var versionLabel = %VersionLabel
@onready var SUBMENU = {
	MAIN = %MainScreen,
}

var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")
var LICENSES_WINDOW_SCENE:PackedScene = load("res://ui/licenses_window.tscn")
var VERSION_WARNING_DIALOG_SCENE:PackedScene = load("res://ui/versionwarning_dialog.tscn")
var previousSaveFile:int = 0

# === Virtuals ===
func _ready():
	previousSaveFile = int(Config.getSetting("previousSaveFile", 0))
	var previousSaveFileExists:bool = UserData.doesDracominoFileExist(previousSaveFile)
	
	showSubmenu()
	
	updateVersionInfo()
	var btn_exit:Button = %Button_Exit
	if btn_exit is Button:
		btn_exit.visible = !Config.isWeb
		var tree:SceneTree = get_tree()
		if tree:
			btn_exit.pressed.connect(tree.quit)

	var btn_continue:Button = %Button_Continue
	var saveInfoPanel_continue:SaveInfoPanel = %SaveInfoPanel_Continue

	# Continue button
	if btn_continue is Button:
		btn_continue.disabled = !previousSaveFileExists
		if not btn_continue.disabled:
			btn_continue.pressed.connect(_on_ButtonContinue_pressed)

		# Save info panel
		if saveInfoPanel_continue is SaveInfoPanel:
			if previousSaveFileExists:
				saveInfoPanel_continue.displaySaveInfo(previousSaveFile)
				btn_continue.mouse_entered.connect(_on_ButtonContinue_focus_entered.bind(saveInfoPanel_continue.show))
				btn_continue.mouse_exited.connect(_on_ButtonContinue_focus_entered.bind(saveInfoPanel_continue.hide))
				btn_continue.focus_entered.connect(_on_ButtonContinue_focus_entered.bind(saveInfoPanel_continue.show))
				btn_continue.focus_exited.connect(_on_ButtonContinue_focus_entered.bind(saveInfoPanel_continue.hide))
			else:
				saveInfoPanel_continue.hide()

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
func _on_ButtonPlay_pressed() -> void:
	Game.newGame()

func _on_ButtonChangeLog_pressed():
	var _window:Window = CHANGELOG_WINDOW_SCENE.instantiate() as Window
	_window.popup_exclusive_centered(self)

func _on_ButtonLicenses_pressed():
	var _window:Window = LICENSES_WINDOW_SCENE.instantiate() as Window
	_window.popup_exclusive_centered(self)

func _on_ButtonContinue_pressed():	
	var data = UserData.loadDracominoDataFromFile(previousSaveFile, showErrorMessage)

	# TODO: Check if version compatible
	
	Game.loadGameData(data)

func _on_ButtonContinue_focus_entered(fn:Callable) -> void:
	if fn.is_valid():
		fn.call()

func showErrorMessage(message:String):
	var errorDialog:AcceptDialog = VERSION_WARNING_DIALOG_SCENE.instantiate()
	errorDialog.dialog_text = message

	add_child(errorDialog)
	errorDialog.popup_centered()
	errorDialog.visibility_changed.connect(errorDialog.queue_free)
