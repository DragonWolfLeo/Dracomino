class_name DialoguePortraitCollection extends Node2D

### Variables ###
var currentExpression:String

### Virtuals ###
func _init() -> void:
	child_entered_tree.connect(
		func(node):
			if node is DialoguePortraitForm:
				var form := node as DialoguePortraitForm
				if form.isExclusive:
					if not form.eligible_changed.is_connected(_on_exclusiveChild_eligible_changed):
						form.eligible_changed.connect(_on_exclusiveChild_eligible_changed)
	)
	child_exiting_tree.connect(
		func(node):
			if node is DialoguePortraitForm:
				var form := node as DialoguePortraitForm
				if form.eligible_changed.is_connected(_on_exclusiveChild_eligible_changed):
					form.eligible_changed.disconnect(_on_exclusiveChild_eligible_changed)
	)

### Functions ###
func setExpression(expression:String = "", isInitial:bool = false) -> void:
	if currentExpression == expression: return
	var exclusiveForms:Array[DialoguePortraitForm] = []
	var exclusiveForm:DialoguePortraitForm
	for child:Node in get_children():
		if child.has_method("setExpression"):
			child.call("setExpression", expression, isInitial)

	currentExpression = expression

### Events ###
func _on_exclusiveChild_eligible_changed():
	var enforceExclusion:bool = false
	for child:Node in get_children():
		if child is DialoguePortraitForm:
			var form := child as DialoguePortraitForm
			if form.isExclusive and form.isEligible():
				form.exclude(enforceExclusion)
				enforceExclusion = true