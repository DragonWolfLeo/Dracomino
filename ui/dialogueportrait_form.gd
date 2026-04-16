class_name DialoguePortraitForm extends Sprite2D

signal eligible_changed()

### Variables ###
@export var filenamePrefix:String
@export var warnIfTextureNotFound:bool = true
@export var enableCondition:String = ""
@export var disableCondition:String = ""
@export var isExclusive:bool = true ## Hide sibling forms if visible? Disable if layering is desired.

var excluded:bool = false: set = _set_excluded
var eligible:bool = false: set = _set_eligible
var currentExpression:String
var PORTRAIT_DIRECTORY:String = "res://assets/art/dialogueportrait/"

### Virtuals ###
func _ready() -> void:
	# Auto-set prefix if you haven't already set it
	if filenamePrefix.is_empty():
		if texture:
			filenamePrefix = texture.resource_path.get_file().get_basename()
		else:
			printerr("DialoguePortraitForm._ready: No filenamePrefix set and could not auto-set")

	FlagManager.stateflag_changed.connect(_on_stateflag_changed)
	_on_stateflag_changed()

func _enter_tree() -> void:
	if not isExclusive or get_parent() is not DialoguePortraitCollection:
		excluded = false

### Functions ###
func _loadPortraitTexture(expression:String = "") -> Texture2D:
	if expression: expression = "-" + expression
	var path = "{dir}{prefix}{suffix}.png".format({
		dir=PORTRAIT_DIRECTORY,
		prefix=filenamePrefix,
		suffix=expression
	})
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if warnIfTextureNotFound:
		print("DialoguePortraitForm._loadPortraitTexture: Did not find texture resource {prefix}{suffix}.png".format({prefix=filenamePrefix,suffix=expression}))
	return null
			
func setExpression(expression:String = "", isInitial:bool = false) -> void:
	expression = expression.to_lower()
	if currentExpression == expression: return
	
	# Find texture for expression
	var tex:Texture2D = _loadPortraitTexture(expression)
	if !tex:
		# Did not find expression, so load default
		expression = ""
		tex = _loadPortraitTexture(expression)
	if !tex:
		# Not even default exists. There's a problem
		printerr("DialoguePortraitForm.setExpression: Could not load default texture for {prefix}".format({prefix=filenamePrefix}))
		return
	texture = tex
		
	if currentExpression == expression: return # Yeah this is here again in case it defaulted and didn't change
	currentExpression = expression

func exclude(isExcluded:bool = true) -> void:
	excluded = isExcluded

func isEligible() -> bool:
	return eligible

func meetsCondition() -> bool:
	var result:bool = true
	if disableCondition:
		result = !FlagManager.isFlagSet(disableCondition)
		if not result:
			return result

	if enableCondition:
		result = FlagManager.isFlagSet(enableCondition)
	return result

### Events
func _on_stateflag_changed(_flag:String = ""):
	eligible = meetsCondition()
	if excluded:
		return

	visible = eligible

func _set_excluded(value:bool):
	if value == excluded: return
	excluded = value
	if excluded:
		visible = false
	else:
		visible = meetsCondition()

func _set_eligible(value:bool):
	if value == eligible: return
	eligible = value
	eligible_changed.emit()