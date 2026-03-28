extends VBoxContainer

@onready var btnChangelog:Button = %Btn_Changelog
@onready var btnRestart:Button = %Btn_Restart
@onready var btnQuit:Button = %Btn_Quit

var CHANGELOG_WINDOW_SCENE:PackedScene = load("res://ui/changelog_window.tscn")

func _ready() -> void:
	btnQuit.disabled = Config.isWeb
	btnChangelog.pressed.connect(_on_btnChangelog_pressed)
	btnRestart.pressed.connect(_on_btnRestart_pressed)
	btnQuit.pressed.connect(_on_btnQuit_pressed)

func _on_btnChangelog_pressed() -> void:
	var _changelogWindow:Window = CHANGELOG_WINDOW_SCENE.instantiate() as Window
	_changelogWindow.popup_exclusive_centered(self)

func _on_btnRestart_pressed() -> void:
	SignalBus.getSignal("restartGame").emit()

func _on_btnQuit_pressed() -> void:
	get_tree().quit()