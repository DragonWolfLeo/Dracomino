class_name SaveInfoPanel extends PanelContainer

@onready var lineEdit_SaveSlotName:LineEdit = %LineEdit_SaveSlotName
@onready var button_Load:Button = %Button_Load
@onready var button_Delete:Button = %Button_Delete
@onready var saveInfoContainer:Control = %SaveInfoContainer
@onready var errorContainer:Control = %ErrorContainer
@onready var emptyFileContainer:Control = %EmptyFileContainer
@onready var fileButtonBar:Control = %FileButtonBar

var fileNum:int = 0: set = displaySaveInfo

var deleteConfirmationWindow:ConfirmationDialog

static var VERSION_WARNING_DIALOG_SCENE:PackedScene = load("res://ui/versionwarning_dialog.tscn")
static var MONTHS:Dictionary[int, StringName] = {
	1: "January",
	2: "February",
	3: "March",
	4: "April",
	5: "May",
	6: "June",
	7: "July",
	8: "August",
	9: "September",
	10: "October",
	11: "November",
	12: "December",
}

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	UserData.saveIndex_updated.connect(displaySaveInfo)
	# Save slot name
	if lineEdit_SaveSlotName is LineEdit:
		lineEdit_SaveSlotName.focus_exited.connect(_on_lineEdit_saveSlotName_updated.bind(lineEdit_SaveSlotName))
		lineEdit_SaveSlotName.text_submitted.connect(_on_lineEdit_saveSlotName_updated.bind(lineEdit_SaveSlotName).unbind(1))
	# Load button
	if button_Load:
		button_Load.pressed.connect(loadFile)
	# Delete button
	if button_Delete is Button:
		button_Delete.pressed.connect(_on_Button_Delete_pressed)

func displaySaveInfo(_fileNum:int = fileNum) -> void:
	fileNum = _fileNum
	var saveInfo:Variant = UserData.saveIndex.get(str(fileNum))
	if saveInfo is Dictionary:
		var isError:bool = bool(saveInfo.get("error", false))
		saveInfoContainer.visible = not isError
		errorContainer.visible = isError
		fileButtonBar.show()
		emptyFileContainer.hide()
		if not isError:
			update(saveInfo)
	else:
		saveInfoContainer.hide()
		errorContainer.hide()
		fileButtonBar.hide()
		emptyFileContainer.show()

func update(data:Dictionary):
	# Save slot name
	if lineEdit_SaveSlotName is LineEdit:
		lineEdit_SaveSlotName.text = str(data.get("saveSlotName", "File %s"%fileNum))
	# Game Type and Chapter Name
	var label_GameType:Label = %Label_GameType
	if label_GameType is Label:
		label_GameType.text = str(data.get("gameType", "Classic"))
		if data.get("mainChapterName"):
			label_GameType.text += " - " + str(data["mainChapterName"])
	# Date
	var label_Date:Label = %Label_Date
	if label_Date is Label:
		label_Date.text = getTimeString(int(data.get("timestamp", 0)))
		label_Date.visible = not label_Date.text.is_empty()
	# Progress
	var label_Progress:Label = %Label_Progress
	if label_Progress is Label:
		label_Progress.text = "Progress: {numChecked} / {totalLocations}".format({
			numChecked = int(data.get("numChecked", 0)),
			totalLocations = int(data.get("totalLocations", 0)),
		})
	# Version
	var label_Version:Label = %Label_Version
	if label_Version is Label:
		if data.get("generatorVersion"):
			label_Version.text = "Generated on APWorld V%s"%str(data["generatorVersion"])
		else:
			label_Version.text = "V%s"%str(data.get("versionNum"))
	# Archipelago
	var tag_Archipelago:CanvasItem = %Tag_Archipelago
	if tag_Archipelago is CanvasItem:
		tag_Archipelago.visible = bool(data.get("isAP", false))
	# Completed
	var tag_Completed:CanvasItem = %Tag_Completed
	if tag_Completed is CanvasItem:
		tag_Completed.visible = bool(data.get("victory", false))

func getTimeString(timestamp:int) -> String:
	if timestamp:
		var dict:Dictionary = Time.get_date_dict_from_unix_time(timestamp)
		dict["month"] = MONTHS.get(dict.get("month"))
		return "{day} {month} {year}".format(dict)
	return ""

func showErrorMessage(message:String):
	var errorDialog:AcceptDialog = VERSION_WARNING_DIALOG_SCENE.instantiate()
	errorDialog.dialog_text = message

	add_child(errorDialog)
	errorDialog.popup_centered()
	errorDialog.visibility_changed.connect(errorDialog.queue_free)

func loadFile():	
	var data:Dictionary = UserData.loadDracominoDataFromFile(fileNum, showErrorMessage)
	Game.loadGameData(data)

# === Events ===
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		displaySaveInfo()

func _on_lineEdit_saveSlotName_updated(lineEdit:LineEdit) -> void:
	UserData.modifySaveInfo(fileNum, {saveSlotName = lineEdit.text if lineEdit.text else "File %s"%fileNum})

func _on_Button_Delete_pressed() -> void:
	var saveSlotName:StringName = "File %s"%fileNum
	var saveInfo:Dictionary = UserData.saveIndex.get(str(fileNum), {})
	if saveInfo is Dictionary:
		if saveInfo.has("saveSlotName"):
			saveSlotName = str(saveInfo["saveSlotName"])
	deleteConfirmationWindow = ConfirmationDialog.new()
	deleteConfirmationWindow.title = "Delete file confirmation"
	deleteConfirmationWindow.dialog_text = "Are you sure you want to delete file \"%s\"?"%saveSlotName
	deleteConfirmationWindow.ok_button_text = "Yes, delete it!"
	
	
	# add_child(deleteConfirmationWindow)
	deleteConfirmationWindow.popup_exclusive_centered(self)
	deleteConfirmationWindow.get_cancel_button().grab_focus()
	deleteConfirmationWindow.visibility_changed.connect(deleteConfirmationWindow.queue_free)
	deleteConfirmationWindow.confirmed.connect(UserData.deleteDracominoDataFile.bind(fileNum))
