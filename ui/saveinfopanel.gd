class_name SaveInfoPanel extends PanelContainer

var fileNum:int = 0
func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	# Save slot name
	var lineEdit_saveSlotName:LineEdit = %LineEdit_SaveSlotName
	if lineEdit_saveSlotName is LineEdit:
		lineEdit_saveSlotName.focus_exited.connect(_on_lineEdit_saveSlotName_updated.bind(lineEdit_saveSlotName))
		lineEdit_saveSlotName.text_submitted.connect(_on_lineEdit_saveSlotName_updated.bind(lineEdit_saveSlotName))

func displaySaveInfo(_fileNum:int = fileNum) -> void:
	fileNum = _fileNum
	var saveInfo:Dictionary = UserData.saveIndex.get(str(fileNum), {})
	if saveInfo is Dictionary:
		if saveInfo.get("error"):
			printerr("There was an error displaying save slot info for file ")
		else:
			update(saveInfo)

func _on_lineEdit_saveSlotName_updated(lineEdit:LineEdit) -> void:
	UserData.modifySaveInfo(fileNum, {saveSlotName = lineEdit.text})

func update(data:Dictionary):
	# Save slot name
	var lineEdit_saveSlotName:LineEdit = %LineEdit_SaveSlotName
	if lineEdit_saveSlotName is LineEdit:
		lineEdit_saveSlotName.text = str(data.get("saveSlotName", "File %s"%fileNum))
	# Game Type and Chapter Name
	var label_gameType:Label = %Label_GameType
	if label_gameType is Label:
		label_gameType.text = str(data.get("gameType", "Classic"))
		if data.get("mainChapterName"):
			label_gameType.text += " - " + str(data["mainChapterName"])
	# Date
	var label_date:Label = %Label_Date
	if label_date is Label:
		label_date.text = getTimeString(int(data.get("timestamp", 0)))
		label_date.visible = not label_date.text.is_empty()
	# Progress
	var label_progress:Label = %Label_Progress
	if label_progress is Label:
		label_progress.text = "Progress: {numChecked} / {totalLocations}".format({
			numChecked = int(data.get("numChecked", 0)),
			totalLocations = int(data.get("totalLocations", 0)),
		})
	# Version
	var label_version:Label = %Label_Version
	if label_version is Label:
		if data.get("generatorVersion"):
			label_version.text = "Generated on APWorld V%s"%str(data["generatorVersion"])
		else:
			label_version.text = "V%s"%str(data.get("versionNum"))
	# Archipelago
	var tag_isAP:CanvasItem = %Tag_Archipelago
	if tag_isAP is CanvasItem:
		tag_isAP.visible = data.get("isAP")
	# Completed
	var tag_completed:CanvasItem = %Tag_Completed
	if tag_completed is CanvasItem:
		tag_completed.visible = data.get("victory")


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

func getTimeString(timestamp:int) -> String:
	if timestamp:
		var dict:Dictionary = Time.get_date_dict_from_unix_time(timestamp)
		dict["month"] = MONTHS.get(dict.get("month"))
		return "{day} {month} {year}".format(dict)
	return ""

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		displaySaveInfo()
