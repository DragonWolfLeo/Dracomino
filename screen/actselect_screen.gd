extends CanvasLayer

@onready var buttonContainer:Control = %ButtonContainer
@onready var btn_checkpoint:Button = %Button_Checkpoint
@onready var btn_cancel:Button = %Button_Cancel
@onready var otherActsSection:Control = %OtherActsSection

# === Virtuals ===
func _ready() -> void:
	clearButtonContainer()
	SignalBus.getSignal("openActSelect").connect(show)
	SignalBus.getSignal("restartGame").connect(hide)
	visibility_changed.connect(_on_visibility_changed)
	# Cancel button
	btn_cancel.pressed.connect(hide)
	btn_cancel.focus_entered.connect(SoundManager.play.bind("select"))
	# Checkpoint button
	btn_checkpoint.pressed.connect(SoundManager.play.bind("confirm"))
	btn_checkpoint.pressed.connect(hide, CONNECT_DEFERRED)
	btn_checkpoint.focus_entered.connect(SoundManager.play.bind("select"))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

# === Functions ===
func clearButtonContainer() -> void:
	otherActsSection.hide()
	for child:Node in buttonContainer.get_children():
		child.queue_free()

# === Events ===
func _on_DracominoHandler_campaign_changed(campaign:DracominoHandler.CampaignContext) -> void:
	clearButtonContainer()
	if campaign is DracominoHandler.CampaignContext:
		# Checkpoint button
		btn_checkpoint.pressed.connect(campaign.loadCheckpoint)
		campaign.checkpoint_changed.connect(_on_campaign_checkpoint_changed)
		_on_campaign_checkpoint_changed(campaign.checkpoint)
		# Create act buttons
		for act:DracominoHandler.ActContext in campaign.acts:
			var actButton:Button = Button.new()
			actButton.text = act.prettyName
			actButton.visible = act.selectable
			act.selectable_changed.connect(_on_actButton_selectable_changed.bind(actButton, act != campaign.acts.front()))
			actButton.pressed.connect(act.loadAct)
			actButton.pressed.connect(SoundManager.play.bind("confirm"))
			actButton.pressed.connect(hide, CONNECT_DEFERRED)
			actButton.focus_entered.connect(SoundManager.play.bind("select"))
			if buttonContainer:
				buttonContainer.add_child(actButton)

		if campaign.acts.front() != campaign.checkpoint:
			otherActsSection.show()

func _on_visibility_changed() -> void:
	if visible:
		btn_checkpoint.grab_focus()

func _on_actButton_selectable_changed(isSelectable:bool, btn:Button, showOtherActs:bool = true) -> void:
	if is_instance_valid(btn):
		btn.visible = isSelectable
		if isSelectable and showOtherActs:
			otherActsSection.show()

func _on_campaign_checkpoint_changed(act:DracominoHandler.ActContext) -> void:
	btn_checkpoint.text = act.prettyName

func _on_ClickMask_gui_input(event:InputEvent) -> void:
	# Hide when clicking outside the window
	if event is InputEventMouseButton:
		if event.pressed:
			hide()
