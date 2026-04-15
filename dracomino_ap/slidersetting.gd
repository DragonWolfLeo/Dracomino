@tool
extends MarginContainer

@export var targetSetting:StringName = ""
@export var settingName:String = "Setting Name":
	set(value):
		if settingName == value: return
		settingName = value
		(find_child("Label_SettingName") as Label).text = value
@export var default:float = 1.0:
	set(value):
		if default == value: return
		default = value
		(find_child("HSlider_Amt") as Slider).value = value
@export var minValue:float = 0.2:
	set(value):
		if minValue == value: return
		minValue = value
		(find_child("HSlider_Amt") as Slider).min_value = value
@export var maxValue:float = 8.0:
	set(value):
		if maxValue == value: return
		maxValue = value
		(find_child("HSlider_Amt") as Slider).max_value = value
@export var step:float = 0.1:
	set(value):
		if step == value: return
		step = value
		(find_child("HSlider_Amt") as Slider).step = value

var label_gravityAmt:Label
var slider_amt:Slider
var btn_reset:Button

func _ready() -> void:
	if Engine.is_editor_hint(): return
	slider_amt = find_child("HSlider_Amt") as Slider
	if slider_amt:
		label_gravityAmt = find_child("Label_Amt") as Label
		slider_amt.value_changed.connect(_on_slider_amt_value_changed)
		slider_amt.value = Config.getSetting(targetSetting, 1.0)
		btn_reset = find_child("Btn_Reset") as Button
		if btn_reset:
			btn_reset.pressed.connect(slider_amt.set.bind("value", Config.getDefaultSetting(targetSetting, 1.0)))

func _on_slider_amt_value_changed(value:float) -> void:
	Config.changeSetting(targetSetting, value)
	if label_gravityAmt:
		label_gravityAmt.text = str(value)