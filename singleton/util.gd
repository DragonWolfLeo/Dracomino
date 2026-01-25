class_name DracominoUtil # TODO: Rename to Util when cleaning up GodotAP
extends Node

# Death Link Messages
class DeathLinkMessageTemplate:
	var messageTemplate:String
	var templateFormatValues:Dictionary
	var contextTags:Array[String]
	func _init(_messageTemplate:String = "{player} died"):
		messageTemplate = _messageTemplate
		templateFormatValues = CONSTANTS.CONTEXT_TAGS.GENERIC.duplicate()

	func addContext(_contextTag:StringName) -> DeathLinkMessageTemplate:
		# TODO: Use variadic arguments when upgrading to Godot 4.5
		assert(
			_contextTag in CONSTANTS.CONTEXT_TAGS,
			"DeathLinkMessageTemplate.addContext error: Context tag {_contextTag} in not in CONSTANTS.CONTEXT_TAGS!".format({_contextTag=_contextTag})
		)
		templateFormatValues.merge(CONSTANTS.CONTEXT_TAGS.get(_contextTag, {}), true)
		contextTags.append(_contextTag)
		return self
	
	func addContexts(_contextTags:Array) -> DeathLinkMessageTemplate:
		for tag in _contextTags:
			addContext(tag)
		return self


static func generateDeathlinkMessage(category:String = "TOP", contextTags:Array = [], formatValues:Dictionary = {}) -> String:
	if not category in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES:
		printerr("DracominoUtil.generateDeathlinkMessage error: {category} not found in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES!".format({category=category}))
	var validTemplates:Array[DeathLinkMessageTemplate] = []
	for template in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES.get(category, []):
		if template is DeathLinkMessageTemplate:
			if template.contextTags.size():
				var skip:bool = false
				for tag in template.contextTags:
					if not tag in contextTags:
						skip = true
						break
				if skip: continue
			validTemplates.append(template)
	
	# Choose a random valid template
	var message:String = "{player} died."
	if validTemplates.size():
		var template = validTemplates[randi_range(0, validTemplates.size() - 1)]
		formatValues = formatValues.merged(template.templateFormatValues)
		message = template.messageTemplate
	else:
		printerr("DracominoUtil.generateDeathlinkMessage error: No death link message templates are valid with category ", category, " and tags ", contextTags) 

	message = message.format(formatValues)
	return message

class DeathContext:
	var category:String
	var itemContext:DracominoHandler.StateItem
	var contextTags:Array[String]
	var formatValues:Dictionary = {}
	func _init(_category:String, _itemContext:DracominoHandler.StateItem = null) -> void:
		if _category in CONSTANTS.DEATHLINK_MESSAGE_TEMPLATES:
			category = _category
		else:
			printerr("DeathContext._init error: {category} is not a valid category!".format({category=_category}))
		itemContext = _itemContext

	func addContext(_contextTag:StringName) -> DeathContext:
		# TODO: Use variadic arguments when upgrading to Godot 4.5
		if _contextTag in CONSTANTS.CONTEXT_TAGS:
			contextTags.append(_contextTag)
		else:
			printerr("DeathContext.addContext error: {contextTag} is not a valid context tag!".format({contextTags=_contextTag}))
		return self
	
	func addContexts(_contextTags:Array) -> DeathContext:
		for tag in _contextTags:
			addContext(tag)
		return self

# Volume set helper
static func setVolume(busName:String, percent:float):
	var weight:float = percent/100
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(busName), lerpf(-60, 0, weight))