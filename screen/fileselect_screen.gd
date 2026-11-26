extends Control
@onready var saveInfoPanel:SaveInfoPanel = %SaveInfoPanel
var MENU_BUTTON_SCRIPT:Script = load("res://ui/menubutton.gd")

# === Virtuals ===
func _ready() -> void:
	var button_Back:Button = %Button_Back
	if button_Back is Button:
		button_Back.pressed.connect(hide)

	var fileButtonContainer:Control = %FileButtonContainer
	if fileButtonContainer is Control:
		for child in fileButtonContainer.get_children():
			child.queue_free()

		var saves:Array[Dictionary] = []
		for k:StringName in UserData.saveIndex.keys():
			saves.append({
				fileNum = k,
				timestamp = int(UserData.saveIndex[k].get("timestamp", 0)),
			})

		saves.sort_custom(
			func(a:Dictionary, b:Dictionary):
				return a["timestamp"] > b["timestamp"]
		)

		for v:Dictionary in saves:
			var btn:Button =  Button.new()
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if MENU_BUTTON_SCRIPT:
				btn.set_script(MENU_BUTTON_SCRIPT)
			var fileNum:StringName = v["fileNum"]
			_changeButtonTextToIndexSaveSlotName(btn, fileNum)
			var saveInfo_updated:Signal = SignalBus.getSignal("saveInfo_updated", int(fileNum))
			var saveInfo_deleted:Signal = SignalBus.getSignal("saveInfo_deleted", int(fileNum))
			saveInfo_updated.connect(_changeButtonTextToIndexSaveSlotName.bind(btn, fileNum))
			saveInfo_deleted.connect(btn.queue_free, CONNECT_ONE_SHOT)
			btn.tree_exiting.connect(saveInfo_updated.disconnect.bind(_changeButtonTextToIndexSaveSlotName), CONNECT_ONE_SHOT)
			if saveInfoPanel is SaveInfoPanel:
				btn.pressed.connect(saveInfoPanel.displaySaveInfo.bind(int(fileNum)))
				btn.pressed.connect(saveInfoPanel.giveFocusToLoadButton)
				btn.focus_entered.connect(saveInfoPanel.displaySaveInfo.bind(int(fileNum)))
			fileButtonContainer.add_child(btn)

		if saves.size() and saveInfoPanel is SaveInfoPanel:
			var recentSave:Dictionary = saves.front()
			saveInfoPanel.displaySaveInfo(int(recentSave.get("fileNum", 0)))

# === Private Functions ===
func _changeButtonTextToIndexSaveSlotName(btn:Button, fileNum:StringName) -> void:
	var saveInfo:Dictionary = UserData.saveIndex.get(fileNum)
	if saveInfo is Dictionary:
		btn.text = str(saveInfo.get("saveSlotName", "File %s"%fileNum))