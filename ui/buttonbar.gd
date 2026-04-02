extends VBoxContainer

@onready var btnChangelog:Button = %Btn_Changelog
@onready var btnTutorial:Button = %Btn_Tutorial
@onready var btnLogic:Button = %Btn_Logic
@onready var btnRestart:Button = %Btn_Restart
@onready var btnQuit:Button = %Btn_Quit

var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")

func _ready() -> void:
	# Disable buttons
	btnQuit.disabled = Config.isWeb
	btnTutorial.hide()
	btnLogic.hide()

	# Connect pressed signals
	btnChangelog.pressed.connect(_on_btnChangelog_pressed)
	btnTutorial.pressed.connect(_on_btnTutorial_pressed)
	btnLogic.pressed.connect(_on_btnLogic_pressed)
	btnRestart.pressed.connect(_on_btnRestart_pressed)
	btnQuit.pressed.connect(_on_btnQuit_pressed)

	# Connect other signals
	SignalBus.getSignal("stateflag_set", "tutorial").connect(btnTutorial.show)
	SignalBus.getSignal("stateflag_set", "tutorial_logic").connect(btnLogic.show)

func _on_btnChangelog_pressed() -> void:
	var _changelogWindow:Window = CHANGELOG_WINDOW_SCENE.instantiate() as Window
	_changelogWindow.popup_exclusive_centered(self)

func _on_btnTutorial_pressed() -> void:
	if not DialogueManager.dialogue:
		DialogueManager.loadDialogue(load("res://dialogue/tutorial.script"))

func _on_btnLogic_pressed() -> void:
	if not DialogueManager.dialogue:
		DialogueManager.loadDialogue(load("res://dialogue/tutorial_logic.script"))

func _on_btnRestart_pressed() -> void:
	SignalBus.getSignal("restartGame").emit()

func _on_btnQuit_pressed() -> void:
	get_tree().quit()