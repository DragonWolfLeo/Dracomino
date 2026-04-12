extends Label

var targetBalance:int = 0
var displayedBalance:int = 0:
	set(value):
		if displayedBalance == value: return
		displayedBalance = value
		text = str(displayedBalance)

@export var displaySignal:StringName
@export var displayDuration:float = 5.0
@export var displayTarget:CanvasItem
@export var currencyFlag:String
@export var useTween:bool = false
@export var balanceTweenDuration:float = 0.5
var tween:Tween
var displayTween:Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	displayedBalance = FlagManager.getTotalCountAmount(currencyFlag)
	if displaySignal:
		if displayTarget:
			displayTarget.hide()
		else:
			hide()
		SignalBus.getSignal(displaySignal).connect(_on_displaySignal)
	SignalBus.getSignal("stateflag_changed", currencyFlag).connect(
		func():
			targetBalance = FlagManager.getTotalCountAmount(currencyFlag)
			if useTween and is_visible_in_tree():
				if tween: tween.kill()
				tween = create_tween()
				tween.set_pause_mode(tween.TWEEN_PAUSE_PROCESS)
				tween.tween_property(self, "displayedBalance", targetBalance, balanceTweenDuration).from_current()
			else:
				displayedBalance = targetBalance
	)

func _on_displaySignal() -> void:
	var target:CanvasItem = displayTarget if displayTarget else self
	target.show()
	if displayDuration <= 0:
		return
	if displayTween: displayTween.kill()
	displayTween = target.create_tween()
	displayTween.tween_callback(target.hide).set_delay(displayDuration)
