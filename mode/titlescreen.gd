extends CanvasLayer

#signal game_started()
@onready var label = $MainControl/MainScreen/Label
@onready var mainControl:Control = $MainControl
@onready var SUBMENU = {
	MAIN = $MainControl/MainScreen,
	CHANGELOG = $MainControl/MenuLayout/ChangeLogContainer,
	PREFERENCES = $MainControl/MenuLayout/PrefsContainer,
	FILESELECT = $MainControl/MenuLayout/FileSelectContainer,
	VERSIONWARNING = $MainControl/MenuLayout/VersionWarningContainer,
}
@onready var scrollContainer:ScrollContainer = find_child("ChangeLogScrollContainer")

# Called when the node enters the scene tree for the first time.
func _ready():
#	Game.setMode(self)
	find_child("Button_Exit").visible = !Config.isWeb
	showSubmenu()
	
	visibility_changed.connect(func():
		process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	)
	
	updateVersionAndChangeLog()		
	(find_child("Button_Continue") as Button).disabled = !UserData.doesSaveFileExist()
	

func grabFocus():
	mainControl.grab_focus()
	
func updateVersionAndChangeLog():
	var changelog:String = load("res://changelog.txt").text.replace("\r","")
	var regex := RegEx.create_from_string("(\\S| )+") # Should get first line containing version and date
	var rm := regex.search(changelog)
	if rm and rm.strings.size(): label.text = label.text.format({
		versionNum=rm.strings[0],
		patchInfo = "",
	})
	SUBMENU.CHANGELOG.find_child("ChangeLog").text = changelog

func showSubmenu(menu:Control = null):
	# Hide all menus
	for v in SUBMENU.values():
		v.hide()
	
	# Show the one we want
	if !menu: menu = SUBMENU.get("MAIN")
	if menu: menu.show()
	
	grabFocus()
	match menu:
		SUBMENU.CHANGELOG:
			scrollContainer.grab_focus()
	
###### EVENTS ######	
func _on_Control_gui_input(event:InputEvent):
	if (
		event.is_action_pressed("ui_accept") 
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
	):
		mainControl.find_next_valid_focus().grab_focus()

func _on_ButtonNew_pressed():
	get_viewport().set_input_as_handled()
	if UserData.doesSaveFileExist():
		showSubmenu(SUBMENU.FILESELECT)
	else:
		Game.newGame()


func _on_ButtonPrefs_pressed():
	showSubmenu(SUBMENU.PREFERENCES)


func _on_ButtonExit_pressed():
	get_tree().quit()


func _on_ButtonChangeLog_pressed():
	showSubmenu(SUBMENU.CHANGELOG)

func _on_x_pressed():
	showSubmenu()

var scrollStrength:float = 0.0
const SCROLL_SPEED := 5.0
func _process(_delta):
		scrollContainer.scroll_vertical+=ceil(scrollStrength*SCROLL_SPEED)

func _on_ScrollContainer_gui_input(event:InputEvent):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("back"):
		showSubmenu()
		
	scrollStrength = event.get_action_strength("ui_down") - event.get_action_strength("ui_up")


func _on_ButtonYesStartNew_pressed():
	get_viewport().set_input_as_handled()
	Game.newGame()

@onready var _VERSIONWARNING_TEMPLATE:String = SUBMENU.VERSIONWARNING.find_child("Label_VersionWarning").text
func _on_ButtonContinue_pressed():
	get_viewport().set_input_as_handled()
	
	if not FileAccess.file_exists(Config.SAVEFILEPATH):
		print("There's no file to load!!!")
		return # Error! We don't have a save to load.	
	
	var data = UserData.loadDataFromFile(Config.SAVEFILEPATH)
	
	if UserData.isNewVersion(data):
		SUBMENU.VERSIONWARNING.find_child("Label_VersionWarning").text = _VERSIONWARNING_TEMPLATE.format({
			versionNum = data.get("versionNum","(undefined)")
		})
		showSubmenu(SUBMENU.VERSIONWARNING)
		return
	
	Game.loadGameData(data)


func _on_PrefsContainer_x_pressed():
	Config.saveConfig()
	showSubmenu()
