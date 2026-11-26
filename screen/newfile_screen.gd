extends Control

@onready var button_Start:Button = %Button_Start
@onready var lineEdit_SaveSlotName:LineEdit = %LineEdit_SaveSlotName

func _ready() -> void:
	var button_Back:Button = %Button_Back
	if button_Back is Button:
		button_Back.pressed.connect(hide)
	
	if button_Start is Button:
		button_Start.pressed.connect(_on_Button_Start_pressed)

	visibility_changed.connect(_on_visibility_changed)

func _on_Button_Start_pressed() -> void:
	Game.targetSaveFileNum = 1
	while UserData.saveIndex.has(str(Game.targetSaveFileNum)):
		Game.targetSaveFileNum += 1
	Game.targetSaveSlotName = "File %s"%Game.targetSaveFileNum
	if lineEdit_SaveSlotName is LineEdit:
		if not lineEdit_SaveSlotName.text.is_empty():
			Game.targetSaveSlotName = lineEdit_SaveSlotName.text
	print("Making a new game on slot ", Game.targetSaveFileNum)
	Game.newGame()

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and lineEdit_SaveSlotName is LineEdit:
		lineEdit_SaveSlotName.text = DracominoUtil.generateRandomSaveSlotName()
