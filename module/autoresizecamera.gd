extends Camera2D

@export var heightThreshold:float = (Board.BOUNDS.size.y + 6) * 16
@export var zoomMultiplier:int = 1
@export var enableFlag:String = ""
@export var disableFlag:String = ""
@export var soundToPlay:StringName = ""
var masterControl:Control

func _enter_tree() -> void:
	if not masterControl:
		masterControl = get_viewport().get_parent() as Control

	SignalBus.getSignal("setting_changed", "auto_scaling").connect(_on_resized)
	SignalBus.getSignal("setting_changed", "scale_amount").connect(_on_resized)
	if masterControl is Control:
		masterControl.resized.connect(_on_resized)
		_on_resized()
	else:
		printerr("autoresize.gd error: no target control found")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if enableFlag:
		SignalBus.getSignal("stateflag_set", enableFlag).connect(set.bind("enabled", true))
		if soundToPlay:
			SignalBus.getSignal("stateflag_set", enableFlag).connect(SoundManager.play.bind(soundToPlay))
		SignalBus.getSignal("stateflag_cleared", enableFlag).connect(set.bind("enabled", false))
	elif disableFlag:
		SignalBus.getSignal("stateflag_set", disableFlag).connect(set.bind("enabled", false))
		SignalBus.getSignal("stateflag_cleared", disableFlag).connect(set.bind("enabled", true))

func _on_resized() -> void:
	await get_tree().process_frame
	var rect = get_viewport_rect()
	var scaleMultiplier:float = (
		max(1, floor(rect.size.y*zoomMultiplier/ heightThreshold)) if Config.getSetting("auto_scaling", true)
		else zoomMultiplier*Config.getSetting("scale_amount", 1.0)
	)
	zoom = Vector2(scaleMultiplier, scaleMultiplier)
