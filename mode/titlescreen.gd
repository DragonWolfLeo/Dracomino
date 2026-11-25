extends Control

#signal game_started()
@onready var versionLabel = %VersionLabel
@onready var SUBMENU:Dictionary[StringName, Control] = {
	MAIN = %MainScreen,
	FILE_SELECT = %FileSelectScreen,
}

var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")
var LICENSES_WINDOW_SCENE:PackedScene = load("res://ui/licenses_window.tscn")

# === Virtuals ===
func _ready():
	var savesExist:bool = UserData.doSavesExist()
	
	for v:Control in SUBMENU.values():
		v.hidden.connect(_on_submenu_hidden.bind(v), CONNECT_DEFERRED)
	showSubmenu()
	
	updateVersionInfo()
	var btn_exit:Button = %Button_Exit
	if btn_exit is Button:
		btn_exit.visible = !Config.isWeb
		var tree:SceneTree = get_tree()
		if tree:
			btn_exit.pressed.connect(tree.quit)

	var btn_continue:Button = %Button_Continue

	# Continue button
	if btn_continue is Button:
		btn_continue.disabled = !savesExist
		btn_continue.pressed.connect(showSubmenu.bind(SUBMENU.FILE_SELECT))

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

func showSubmenu(menu:Control = SUBMENU.MAIN) -> void:
	# Hide all menus
	for v:Control in SUBMENU.values():
		v.visible = menu == v

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

func _on_ButtonContinue_focus_entered(fn:Callable) -> void:
	if fn.is_valid():
		fn.call()

func _on_submenu_hidden(menu:Control) -> void:
	for v:Control in SUBMENU.values():
		if v.visible:
			return
	# Return to main menu if no menu is visible
	showSubmenu()
