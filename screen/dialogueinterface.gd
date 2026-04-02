extends Control

signal started()
signal finished()
signal portrait_changed()

@onready var nameLabel:Label = $DialogueGroup/DialoguePanel/DialogueContainer/NameLabel
@onready var noNameSpacer:Control = $DialogueGroup/DialoguePanel/DialogueContainer/NoNameSpacer
@onready var dialogueLabel:RichTextLabel = $DialogueGroup/DialoguePanel/DialogueContainer/DialogueLabel
@onready var choiceContainer:VBoxContainer = $DialogueGroup/ChoiceContainer
@onready var portraitContainer:Control = $DialogueGroup/DialoguePanel/PortraitContainer
@onready var portraitContainerRight:Control = $DialogueGroup/DialoguePanel/PortraitContainerRight
@onready var dialogueGroup:Control = $DialogueGroup
@onready var panelDelayTimer:Timer = $PanelDelayTimer
var portrait:CanvasItem
var CHOICE_LABEL_SCENE_RESOURCE_PATH := "res://ui/choicelabel.tscn"
var SHOW_NAME_LABEL:bool = false

class DialogueState:
	var currentSpeaker
	var targetLine:String = ""
	var textTimer:float = 0
	var textPrintDone:bool = true
	var visibleCharacters:int = 0
	var totalCharacters:int = 0
	var speakerDir:int = -2
	var skippable:bool = false
	
	var formatValues:Dictionary
	var resourcePath:String = ""

	func _init() -> void:
		formatValues = CONSTANTS.DIALOGUE_FORMAT_TEMPLATE.duplicate()

var TEXT_SPEED = 0.015
var IMAGEOVERLAY_SHIFT := Vector2(128, 0)
	
var dialogue:Dialogue:
	get:
		return DialogueManager.dialogue
var state := DialogueState.new()

var _was_focused:bool = false

# === Virtuals===
func _ready():
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_updated.connect(_on_dialogue_updated)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.speaker_updated.connect(updatePortrait)
	SignalBus.getSignal("stateflag_set","game_focus").connect(set_process.bind(true))
	SignalBus.getSignal("stateflag_cleared","game_focus").connect(set_process.bind(false))
	SignalBus.getSignal("stateflag_set","game_focus").connect(set.bind("_was_focused", true), CONNECT_DEFERRED)
	SignalBus.getSignal("stateflag_cleared","game_focus").connect(set.bind("_was_focused", false), CONNECT_DEFERRED)

func _process(delta):
	# Print text procedurally
	if state.textPrintDone: return
	state.textTimer += delta
	while state.textTimer > TEXT_SPEED:
		state.textTimer -= TEXT_SPEED
		state.visibleCharacters += 1
		dialogueLabel.visible_characters = state.visibleCharacters
		if state.visibleCharacters >= state.totalCharacters:
			state.textPrintDone = true
			panelDelayTimer.start()
			break

# === Functions ===
func resetInterface():
	Overlay.hideImage(true)
	# Clear portrait container
	for child in portraitContainer.get_children():
		child.queue_free()
	for child in portraitContainerRight.get_children():
		child.queue_free()

	# Reset variables
	state = DialogueState.new()
	
func updateDialogue(line):
	if get_parent().visible: grab_focus() # Only grab focus if a prompt isn't trying to grab one
	state.textPrintDone = false if line.body else true
	state.visibleCharacters = 0
	state.targetLine = line.body.format(state.formatValues)
	dialogueLabel.text = state.targetLine
	state.totalCharacters = dialogueLabel.get_total_character_count()
	if state.targetLine.length():			
		$DialogueGroup/DialoguePanel.show()
	else:
		$DialogueGroup/DialoguePanel.hide()
	if SHOW_NAME_LABEL and line.speaker:
		nameLabel.show()
		noNameSpacer.hide()
		nameLabel.text = line.speaker
	else:
		nameLabel.hide()
		noNameSpacer.show()
	# if line.body:
	updatePortrait(line.speaker, line.expression)
	panelDelayTimer.start()

func completeDialoguePrint():
	dialogueLabel.visible_characters = -1
	state.textPrintDone = true

func updateChoices(choices):
	var targetContainer = choiceContainer
	if choices and choices.size():
		state.skippable = false
		choiceContainer.show()
		for child in choiceContainer.get_children():
			child.queue_free()
			
		var promptItems = null
		var promptId
		for choice in choices:
			match choice.type:
				"CHOICE":
					if promptItems != null:
						promptItems.append(choice.mapping)
					else:
						# Normal choice
						if !choice.lines.size(): continue
						var label = load(CHOICE_LABEL_SCENE_RESOURCE_PATH).instantiate()
						label.data = choice
						var line:Dialogue.DialogueLine = choice.lines[0]
						if line != null:
							label.text = line.render().body
						else:
							label.text = ""
						label.text = label.text.format(state.formatValues)
						targetContainer.add_child(label)
						label.pressed.connect(_on_ChoiceLabel_pressed)
				"JUMP":
					# If it displays, then it's an auto-jump
					dialogue.selectChoice(choice)
					return # Anything else doesn't matter
	else:
		choiceContainer.hide()
					
func deletePortrait():
	if is_instance_valid(portrait) and not portrait.is_queued_for_deletion():
		portrait.queue_free()
		portrait = null
	
func updatePortrait(speaker, expression):
	expression = expression.to_lower()
	if expression == "none":
		state.currentSpeaker = null
		deletePortrait()
	elif speaker == state.currentSpeaker:
		setPortraitExpression(expression, false)
		return
		
	else:
		state.currentSpeaker = speaker
	var speakerMappings = {}

	deletePortrait()
		
	var portraitSpeaker = speakerMappings.get(speaker, speaker)
	if portraitSpeaker == "": portraitSpeaker = null
	
	var dir = (
		0 if expression == "none" else
		1 if portraitSpeaker else
		0
	)
	
	if state.speakerDir != dir:
		state.speakerDir = dir
	
	if expression == "none" or portraitSpeaker == null: return
	var respath = "res://ui/dialogueportrait/"+portraitSpeaker+".tscn"
	if !ResourceLoader.exists(respath):
		printerr("Did not find portrait for ", portraitSpeaker)
		return

	portrait = load(respath).instantiate()
	if dir > 0:
		portraitContainer.add_child(portrait)
	else:
		portraitContainerRight.add_child(portrait)
	
	portrait_changed.emit()
	setPortraitExpression(expression, true)

func setPortraitExpression(expression:String = "", isInitial:bool = false) -> void:
	if portrait and portrait.has_method("setExpression"):
		portrait.call("setExpression", expression, isInitial)
	
### 
func isSkippable()->bool:
	return state.skippable
	
### Events ###
func _gui_input(_event: InputEvent):
	if !dialogue: return
	# Give focus to buttons if using keyboard/controller during choices. Must be checked before proceeding
	if (
		has_focus() 
		and _event.is_action_pressed("ui_accept") 
		or _event.is_action_pressed("ui_up") 
		or _event.is_action_pressed("ui_down")
	):
		if dialogue.showingChoices:
			var control = find_next_valid_focus()
			if control: control.grab_focus()
			get_viewport().set_input_as_handled()
			return
	#
	if (
		_event.is_action_pressed("mouse1") 
		or _event.is_action_pressed("back")
		or _event.is_action_pressed("ui_accept")
		or (_event is InputEventScreenTouch and _event.is_pressed())
	):
		get_viewport().set_input_as_handled()
		if not _was_focused:
			_was_focused = true
		elif state.textPrintDone:
			if panelDelayTimer.is_stopped():
				dialogue.proceedDialogue()
			else:
				panelDelayTimer.stop()
		else:
			completeDialoguePrint()

	
func _on_dialogue_updated(line, choices):
	if line != null: updateDialogue(line)
	updateChoices(choices)

func _on_dialogue_started():
	show()
	if !is_visible_in_tree():
		started.emit()
		resetInterface()
		modulate.a = 0
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.05).from_current()
	grab_focus()

func _on_dialogue_ended():
	Overlay.hideImage()
	Overlay.hideCutscene()
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,0), 0.05).from_current()
	await tween.finished
	Overlay.shiftImageOverlay()
	finished.emit()
	
func _on_ChoiceLabel_pressed(data):
	if !dialogue: return
	grab_focus()
	SoundManager.play("select")
	dialogue.selectChoice(data)
		
