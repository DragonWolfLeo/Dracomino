class_name Dialogue
extends Node

signal dialogue_updated(line, choices)
signal dialogue_ended()

var resourcePath:String = ""
var states:Array[DialogueState] = []	
var statePosition:int = 0
var linePosition:int = 0
var activeResponse:DialogueState
var showingChoices:bool = false
var activeChoices:Array[DialogueSection] = []
var queuedNavtags:Array[NavTag] = []
var ended:bool = false
var text:String = ""
var startingState: StringName
var startingResponse: StringName

class DialogueParse:
	var raw:String = ""

class DialogueSectionParse extends DialogueParse:
	var target:DialogueData = null
	var memory:Dictionary[StringName, Variant] = {}

class DialogueData:
	var id:StringName
	var type:StringName
	
class DialogueState extends DialogueData:
	var choices:Array[DialogueSection] = []
	var responses:Array[DialogueState] = []
	var sections:Array[DialogueSection] = []
	var totalLines:int:
		get: return sections.reduce(func(total:int, section:DialogueSection): return total+section.lines.size(), 0)
	func _init():
		type = &"STATE"
	func isEmpty()->bool:
		return choices.is_empty() and sections.is_empty() and responses.is_empty()
	
class DialogueSection extends DialogueData:
	var lines:Array[DialogueLine] = []
	var mapping:StringName
	var condition:DialogueCondition
	var hidden:bool = false
	func meetsCondition() -> bool:
		if hidden: return false
		if condition: return condition.isMet()
		return true

class DialogueLine:
	var speaker:StringName
	var expression:StringName
	var body:String
	var commands:Array[DialogueCommand] = []
	var navtags:Array[NavTag] = []
	var condition:DialogueCondition
	var extensions:Array[DialogueLine] = []

	func meetsCondition(checkExtensions:bool = true) -> bool:
		if checkExtensions:
			for ext:DialogueLine in extensions:
				if ext.meetsCondition(): return true
		if condition: return condition.isMet()
		return true

	func render() -> DialogueLine:
		var renderedLine := DialogueLine.new()
		renderedLine.speaker = speaker
		renderedLine.expression = expression
		# Apply if tags
		var lineParts:PackedStringArray = []
		var prevTrue = false
		if meetsCondition(false):
			lineParts.append(body)
			renderedLine.commands.append_array(commands)
			renderedLine.navtags.append_array(navtags)
			prevTrue = true
		for ext in extensions:
			if prevTrue and ext.condition and ext.condition.isElse: continue
			prevTrue = false
			if !ext.meetsCondition(): continue
			prevTrue = true
			lineParts.append(ext.body.strip_edges())
			renderedLine.commands.append_array(ext.commands)
			renderedLine.navtags.append_array(ext.navtags)
		renderedLine.body = " ".join(lineParts).strip_edges()
		return renderedLine

class DialogueCondition:
	var flag:StringName
	var notFlag:StringName
	var isElse:bool = false
	func isMet() -> bool:
		if (flag.length() and !FlagManager.isFlagSet(flag)): return false
		elif (notFlag.length() and FlagManager.isFlagSet(notFlag)): return false
		return true

class DialogueCommand:
	var type:StringName
	var option:String
	var invisible:bool = false
	var condition:DialogueCondition
	func meetsCondition() -> bool:
		if condition: return condition.isMet()
		return true

class NavTag:
	var id: StringName
	var type: StringName
	var option: String
	var condition:DialogueCondition
	func meetsCondition() -> bool:
		if condition: return condition.isMet()
		return true

class TagDefinition:
	var objectClass
	var categories:Array = []
	var appendTarget:Variant
	var multiline:bool = false
	var mappable:bool = false
	var canBeConditional:bool = false
	var isCondition:bool = false
	var canMakeInline:bool = false

	func _init(_options:Dictionary = {}):
		objectClass = _options.get("objectClass", DialogueSection)
		categories.append_array(_options.get("categories", []))
		appendTarget = _options.get("appendTarget")
		multiline = _options.get("multiline", false)
		mappable = _options.get("mappable", false)
		canBeConditional = _options.get("canBeConditional", false)
		isCondition = _options.get("isCondition", false)
		canMakeInline = _options.get("canMakeInline", false)

class NavTagCommand:
	var fn:Callable
	var invisible:bool = false
	var argHint:String = ""
	func _init(_fn:Callable, _invisible:bool = false):
		fn = _fn
		invisible = _invisible
	func setInvisible(_invisible:bool = true) -> NavTagCommand:
		invisible = _invisible
		return self
	func setArgHint(_argHint:String = "") -> NavTagCommand:
		argHint = _argHint
		return self

# Static Variables
static var NAVTAGS:Dictionary = {}
static var TAGS:Dictionary = {}

## Static Virtuals
static func _static_init() -> void:
	# Add tag defs
	addTagDefinition("STATE", {objectClass = DialogueState, categories = ["state", "choiceTarget", "sectionContainer"], appendTarget = "states", multiline = true})
	addTagDefinition("RESPONSE", {objectClass = DialogueState, categories = ["choiceTarget", "sectionContainer"], appendTarget = {"state": "responses"}, multiline = true})
	for t:StringName in ["CHOICE", "PROMPT", "JUMP"]:
		addTagDefinition(t, {categories = ["sectionContainer"], appendTarget = {"choiceTarget": "choices"}, canBeConditional = true, mappable = true })
	for t:StringName in ["IF", "ELSE"]:
		addTagDefinition(t, {canMakeInline = true, multiline = true, isCondition = true})
	addTagDefinition("ALWAYS", {canMakeInline = true, multiline = true})

	# Add navtag defs
	addNavTagCommand("REVEALCHOICE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.revealChoice(_navtag.id)).setInvisible().setArgHint("id")
	addNavTagCommand("HIDECHOICE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.hideChoice(_navtag.id)).setInvisible().setArgHint("id")
	addNavTagCommand("REMAPCHOICE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.remapChoice(_navtag.id, _navtag.option)).setArgHint("id mapping")
	addNavTagCommand("NEXTSTATE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.nextState(_navtag.id)).setArgHint("id")
	addNavTagCommand("PREVSTATE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.prevState(_navtag.id)).setArgHint("id")
	addNavTagCommand("GOTOSTATE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.gotoState(_navtag.id)).setArgHint("id")
	addNavTagCommand("REPEATSTATE", func(dialogue:Dialogue, _navtag:NavTag): dialogue.repeatState())
	addNavTagCommand("SKIP", func(dialogue:Dialogue, _navtag:NavTag): dialogue.skip())
	addNavTagCommand("END", func(dialogue:Dialogue, _navtag:NavTag): dialogue.end())
	addNavTagCommand("RESET", func(dialogue:Dialogue, _navtag:NavTag): dialogue.reset())

## Static Functions
static func addTagDefinition(type:StringName, options:Dictionary = {}, force:bool = false) -> TagDefinition:
	type = type.to_upper()
	if !force and TAGS.has(type):
		printerr("Error adding tag {type}: type already exists and is not forced!".format({type = type}))
		return null
	TAGS[type] = TagDefinition.new(options)
	return TAGS[type]

static func addNavTagCommand(type:StringName, fnThatTakesDialogueAndNavTag: Callable, force:bool = false) -> NavTagCommand:
	type = type.to_upper()
	if !force and NAVTAGS.has(type):
		printerr("Error adding navtag {type}: type already exists and is not forced!".format({type = type}))
		return null
	NAVTAGS[type] = NavTagCommand.new(fnThatTakesDialogueAndNavTag)
	return NAVTAGS[type]

## Static Parsing Functions
static func readAtUntil(index:int, until:String, string:String, includeEnd:bool = false) -> String:
	var contents = ""
	var untilFirstChar = until[0]
	for i in range(index, string.length()):
		var c = string[i]
		if c == untilFirstChar:
			var pat = string.substr(i, until.length())
			if pat == until:
				if includeEnd:
					contents += pat
				return contents
		contents += c
	return contents
		
static func addParseToSection(parse:DialogueSectionParse):
	var section:DialogueSection
	if parse.target is DialogueSection: section = parse.target
	if section == null:
		section = DialogueSection.new()
		if parse.target:
			section.type = parse.target.type
	if section == null:
		printerr("Parse has no target section!!! ", parse.raw)
		return
	var sectionContainer:Variant = parse.memory.get("sectionContainer")
		
	var linesToAppend:Array = []
	var mergeIntoTransitionTarget:bool = false
	var tdef:TagDefinition = TAGS.get(parse.target.type)
	var canMakeInline:bool = tdef and tdef.canMakeInline
				
	if tdef and tdef.multiline:
		var lines = parse.raw.split("\n", true)
		for line in lines:
			var dl = parseLine(line)
			if dl:
				if canMakeInline:
					# Allow for inline if tags. Ignore textless tag lines
					var targetArray:Array = linesToAppend
					if sectionContainer is DialogueState:
						# We need to make a section and line to put inline content on
						if sectionContainer.sections.size() == 0:
							sectionContainer.sections.append(DialogueSection.new())
						if sectionContainer.sections.back().lines.size() == 0:
							sectionContainer.sections.back().lines.append(DialogueLine.new())
						var targetLineArr:Array = sectionContainer.sections.back().lines
						var i:int =  targetLineArr.size()-1
						while i >= 0:
							var last = targetLineArr[i]
							if last:
								targetArray = last.extensions
								if last.body.length():
									break
							i -= 1
						mergeIntoTransitionTarget = true
					elif sectionContainer is DialogueSection: # Inline choice rendering
						if sectionContainer.lines.size() and sectionContainer.lines[0] is DialogueLine:
							targetArray = sectionContainer.lines[0].extensions
					targetArray.append(dl)

					# Apply condition of inline if tag to line
					dl.condition = section.condition
				else:
					linesToAppend.append(dl)
			canMakeInline = false
	else:
		var dl = parseLine(parse.raw)
		if dl == null: dl = DialogueLine.new()
		linesToAppend.append(dl)
				
	if linesToAppend.size():
		if sectionContainer is DialogueState:
			if mergeIntoTransitionTarget:
				# Merge inline section into transition target
				section = sectionContainer.sections.back()
			else:
				# Add a section if there's content
				sectionContainer.sections.append(section)
		section.lines.append_array(linesToAppend)
			
static func parseLine(line:String) -> DialogueLine:
	line = line.strip_edges()
	if line:
		var dl:DialogueLine = DialogueLine.new()
		var body:DialogueParse = DialogueParse.new()
		var speaker:DialogueParse
		var expression:bool = false
		var target:DialogueParse = body
		var i = 0
		while i < line.length():
			var c = line[i]
			match c:
				"(":
					if !expression and !speaker:
						var tag = readAtUntil(i+1, ")", line, false)
						i += tag.length() + 1
						expression = true
						dl.expression = tag.strip_edges()
					else: 
						target.raw += c
				":":
					if !speaker:
						speaker = body
						dl.speaker = speaker.raw.strip_edges()
						body = DialogueParse.new()
						target = body
					else:
						target.raw += c
				"[":
					var tag = readAtUntil(i+1, "]", line, false)
					if tag:
						i += tag.length() + 1
						tag = tag.strip_edges()
						var params:PackedStringArray = tag.split(" ", false, 1)
						params[0] = params[0].to_upper()
						params.resize(2) # Fill empty space
						if NAVTAGS.has(params[0]):
							var nt:NavTag = parseNavTagParams(params[1])
							nt.type = params[0]
							dl.navtags.append(nt)
						else: 
							var commandConfig = DracominoCommandManager.getCommand(params[0])
							if commandConfig:
								var command := DialogueCommand.new()
								command.type = params[0]
								if params[1]:
									var parsed:Dictionary = parseParams(params[1])
									command.option = parsed.get("option")
									command.condition = parsed.get("condition")
								command.invisible = commandConfig.invisible
								dl.commands.append(command)
							else:
								# Leave in as BBCode probably
								target.raw += "[" + tag + "]"
					else:
						# Single asterisk, just add
						target.raw += c
				_: 
					target.raw += c
				
			i += 1
		dl.body = body.raw.strip_edges()
		return dl
	return null

static func parseNavTagParams(rawText:String) -> NavTag:
	var nt:NavTag = NavTag.new()
	if rawText:
		var parsed:Dictionary = parseParams(rawText)
		var navtagparams:PackedStringArray = parsed.get("option", "").to_lower().split(" ", false, 1)
		navtagparams.resize(2)
		nt.id = navtagparams[0]
		nt.option = navtagparams[1]
		nt.condition = parsed.get("condition")
	return nt

static func parseTag(rawText:String) -> DialogueData:
	# Split string into type and parameters
	var params:PackedStringArray = rawText.to_lower().split(" ", false, 1)
	# Fill in empty space
	params.resize(2)
	var type = params[0].to_upper()
	var tdef:TagDefinition = TAGS.get(type)

	# Skip unsupported types
	if tdef == null: return

	var ret:DialogueData = tdef.objectClass.new()
	if tdef.isCondition:
		ret["id"] = rawText 
		var condition:DialogueCondition = DialogueCondition.new()
		ret["condition"] = condition
		var ifParams:Array = rawText.to_lower().split(" ", false, 5) as Array
		match ifParams:
			["else", ..]:
				condition.isElse = true
				ifParams.pop_front()
		match ifParams: # Don't require "if" if this is an "else"
			["if", ..]:
				ifParams.pop_front()
		match ifParams:
			[var flag, "not", "if", var notFlag]:
				condition.flag = flag
				condition.notFlag = notFlag
				params[1] = flag + " not " + notFlag
			[var flag, "not", var notFlag]:
				condition.flag = flag
				condition.notFlag = notFlag
				params[1] = flag + " not " + notFlag
			["not", var notFlag, ..]:
				condition.notFlag = notFlag
				params[1] = "not " + notFlag
			[var flag, ..]: 
				condition.flag = flag
				params[1] = flag
	elif params[1]: 
		var parsed:Dictionary = parseParams(params[1])
		ret["id"] = parsed.get("option")
		if tdef.canBeConditional:
			ret["hidden"] = parsed.get("hidden", false)
			ret["condition"] = parsed.get("condition")
		if tdef.mappable:
			ret["mapping"] = ret["id"]

	if ret: ret.type = type
	return ret

static func parseParams(rawText:String) -> Dictionary:
	var ret = {
		option = "",
		hidden = false,
		condition = null,
	}
	var regex:RegEx = RegEx.create_from_string("(?i)\\b(if|hidden)\\b")
	var m:RegExMatch = regex.search(rawText)
	if m:
		ret.option = rawText.substr(0, m.get_start()).strip_edges()
		var params:Array = rawText.substr(m.get_start()).to_lower().split(" ", false) as Array
		ret.condition = DialogueCondition.new()
		match params:
			["if", var flag, "hidden", "if", var notFlag]:
				ret.condition.flag = flag
				ret.condition.notFlag = notFlag
			["if", var flag, "not", "if", var notFlag]:
				ret.condition.flag = flag
				ret.condition.notFlag = notFlag
			["hidden", "if", var notFlag]:
				ret.condition.notFlag = notFlag
			["if", "not", var notFlag]:
				ret.condition.notFlag = notFlag
			["if", var flag]: 
				ret.condition.flag = flag
			["hidden"]: 
				ret.hidden = true
			_: printerr("Failed to parse condition params: "+rawText)
	else:
		ret.option = rawText
	return ret

## Functions
func reset():
	statePosition = 0
	linePosition = 0
	activeResponse = null
	showingChoices = false
	activeChoices.clear()
	ended = false
	updateDialogue()

func startNewSectionParse(target:DialogueData, memory:Dictionary = {}) -> DialogueParse:
	var parse := DialogueSectionParse.new()
	parse.target = target
	var type = target.type
	if TAGS.has(type):
		var tdef:TagDefinition = TAGS[type]
		for category in tdef.categories:
			memory[category] = target
		
		var appendTarget:Variant = tdef.appendTarget
		if appendTarget is String:
			if get(appendTarget) is Array:
				(get(appendTarget) as Array).append(target)
			else:
				printerr("Dialogue.startNewSectionParse: Tried to append {type} section to nonexistent array {appendTarget}".format({type=type, appendTarget=appendTarget}))
		elif appendTarget is Dictionary:
			for k:String in appendTarget:
				var o = memory.get(k)
				var s = appendTarget.get(k)
				if o is Object and s is String:
					if (o as Object).get(s) is Array:
						(o as Object).get(s).append(target)
					else:
						printerr("Dialogue.startNewSectionParse: Tried to append {type} section to nonexistent array {k}.{s}".format({type=type, k=k, s=s}))
				else:
					printerr("Dialogue.startNewSectionParse: Tried to append {type} section to invalid entry {k}.{s}: {o}".format({type=type, k=k, s=s, o=o}))
	else:
		printerr("Dialogue.startNewSectionParse: Could not find tag definition for type ", type)

	parse.memory.merge(memory)
	return parse

func loadDialogue(raw:String, jumpToState:StringName = "", jumpToResponse:StringName = "") -> void:
	text = raw
	startingState = jumpToState
	startingResponse = jumpToResponse
	var memory = {}
	var currentParse:DialogueParse = startNewSectionParse(DialogueState.new(), memory)
	assert(states.size() > 0 and memory.get("state") == states[0])
	var currentLine = 0

	var i = 0
	while i < raw.length():
		var c = raw[i]
		match c:
			# Read tag
			"[":
				var tag:String = readAtUntil(i+1, "]", raw)
				if tag:
					var section = parseTag(tag)
					if section:
						i += tag.length() + 1 # Advance by number of characters processed
						var type = section.type
						var tdef:TagDefinition = TAGS.get(type)
						if tdef:
							addParseToSection(currentParse)
							currentParse = startNewSectionParse(section, memory)
						else:
							printerr("Did not find tag definition for ", type)
					else:
						# This tag will be unprocessed, in case we're using BBCode
						currentParse.raw += c
			# Comments
			"/":
				if i+1 < raw.length():
					var comment
					match raw[i+1]:
						"/": comment = "//"+readAtUntil(i+2, "\n", raw, false)
						"*": comment = "/*"+readAtUntil(i+2, "*/", raw, true)
					if comment:
						# Skip for the duration of the comment
						i += comment.length() - 1
					else:
						currentParse.raw += c # Continue in switch statement
			# Escapes
			"\\":
				if i+1 < raw.length() and raw[i+1] == "\\":
					# Backslash escape
					i += 1
					currentParse.raw += c
				else:
					# Line escape
					var haswhitespace:bool = false
					while i+1 < raw.length() and raw[i+1].strip_edges().is_empty():
						haswhitespace = true
						i += 1
					if not haswhitespace:
						currentParse.raw += c
			"\n":
				# Treat space/tab as continuation
				var haswhitespace:bool = false
				while i+1 < raw.length():
					match raw[i+1]:
						" ", "\t": haswhitespace = true
						"\r": pass
						_: break
					i += 1
				if haswhitespace:
					currentParse.raw = currentParse.raw.strip_edges(false, true) + " "
				else:
					currentParse.raw +=  c
			# All other characters become part of the dialogue
			_: currentParse.raw += c
		# Next character
		i += 1 
		
	# Wrap up last parse
	addParseToSection(currentParse)
	
	# Remove first state if it's just an empty one
	if states.size() and (states[0] as DialogueState).isEmpty():
		states.pop_front()
	
	# Jump to state if it's set
	jumpToState = jumpToState.to_lower()
	if jumpToState.length():
		var success = gotoState(jumpToState, jumpToResponse)
		if !success:
			updateDialogue()
	else:
		updateDialogue()

func proceedDialogue(repeatStateIfNoProgress:bool = false) -> void:
	if !states.size():
		print("Error: No states in dialogue") 
		return

	if ended: return

	# Run queued navtags and return if any
	if queuedNavtags.size():
		for nt in queuedNavtags:
			if activateNavTag(nt):
				queuedNavtags.clear()
				return
		queuedNavtags.clear()
	
	var state:DialogueState = activeResponse if activeResponse else states[statePosition]
	
	var hasLine = false

	var totalLines:int = state.totalLines
	if linePosition < totalLines - 1:
		linePosition += 1
		landOnValidSection(true)
		hasLine = linePosition < totalLines
	else:
		hasLine = false
	
	if hasLine:
		updateDialogue() 
	elif !showingChoices:
		showingChoices = true
		updateDialogue()
	elif repeatStateIfNoProgress:
		repeatState()

func landOnValidSection(skipNewElseSection:bool = false) -> void:
	var state:DialogueState = activeResponse if activeResponse else states[statePosition]
	var lineList = []
	var lineLookup = {}
	for section in state.sections:
		for line in section.lines:
			lineList.append(line)
			lineLookup[line] = section
	
	# If on the first line of a section, check if the section's conditions are met
	while linePosition < lineList.size():
		var line = lineList[linePosition]
		var section = lineLookup[line]
		if line == section.lines[0]:
			if !section.condition or !section.condition.isElse: skipNewElseSection = false
			if skipNewElseSection or !section.meetsCondition():
				linePosition += section.lines.size()
				continue
		return
	return

func updateDialogue() -> void:
	if !states.size():
		print("Error: No states in dialogue") 
		return
	var state = states[statePosition]
	var response = activeResponse
	var sections = activeResponse.sections if activeResponse else state.sections	
	var sectionNum = 0
	var sectionLineIndex = linePosition
	var line = null
	var totalLines = (activeResponse if activeResponse else state).totalLines
	if totalLines and linePosition < totalLines:
		while(sectionLineIndex >= sections[sectionNum].lines.size()):
			sectionLineIndex -= sections[sectionNum].lines.size()
			sectionNum += 1
		line = sections[sectionNum].lines[sectionLineIndex]

	if !line:
		# This could be a state with no dialogue and only choices
		showingChoices = true	
	if !showingChoices:
		var renderedLine := (line as DialogueLine).render()
		
		# Activate commands
		var invisible:bool = !renderedLine.body.length()
		if renderedLine.commands.size():
			for command:DialogueCommand in renderedLine.commands:
				if command.meetsCondition():
					DracominoCommandManager.activateCommand(command.type, command.option)
					if !command.invisible: invisible = false

		# Queue navtag
		queuedNavtags.append_array(renderedLine.navtags)
		if queuedNavtags.size():
			invisible = renderedLine.body.is_empty()
		
		if invisible:
			proceedDialogue()
			return
		dialogue_updated.emit(renderedLine, [])
	elif showingChoices:
		var choiceSets = [state.choices]
		if activeResponse and response.choices.size():
			choiceSets.push_front(response.choices)
		activeChoices.clear()
		for arr in choiceSets:
			if arr is not Array: continue
			for choice in arr:
				if !choice.meetsCondition(): continue
				activeChoices.append(choice)
			if activeChoices.size():
				dialogue_updated.emit(null, activeChoices)
				break
		if activeChoices.size() == 0:
			# Choiceless state. Automatic go to next state
			showingChoices = false
			nextState()

func selectChoice(choice):
	showingChoices = false
	var invisible = true
	if choice.lines.size() and choice.lines[0]:
		var renderedLine = choice.lines[0].render()
		for command:DialogueCommand in renderedLine.commands:
			if command.meetsCondition():
				DracominoCommandManager.activateCommand(command.type, command.option)
				if !command.invisible: invisible = false

		for nt:NavTag in renderedLine.navtags:
			if activateNavTag(nt):
				return

	if !invisible: return
	gotoResponse(choice.mapping)
			
func selectChoiceAtIndex(index:int) -> void:
	selectChoice(activeChoices[index])
	
func gotoResponse(id:StringName, fallback:StringName = "") -> bool:
	showingChoices = false
	linePosition = 0
	id = id.to_lower()
	var state := states[statePosition]
	for i in range(state.responses.size()):
		var response:DialogueState = state.responses[i]
		if response.id == id:
			activeResponse = response
			landOnValidSection()
			updateDialogue()
			return true
	if fallback:
		return gotoResponse(fallback)
	else:
		printerr("Attempted to go to nonexistent response: ", id)
		end()
	return false
			
func activateNavTag(navtag:NavTag) -> bool:
	if !navtag.meetsCondition():
		return false
	
	var navcmd:NavTagCommand = NAVTAGS.get(navtag.type)
	if navcmd:
		navcmd.fn.call(self, navtag)
		if navcmd.invisible: return false
		return true
	return false
	

func nextState(id:StringName = "") -> void:
	if id:
		# Check for next state with same id
		for i in range(statePosition+1, states.size()):
			var state = states[i]
			if state.id == id:
				statePosition = i
				linePosition = 0
				activeResponse = null
				updateDialogue()
				return
	elif statePosition < states.size() - 1:
		statePosition += 1
		linePosition = 0
		activeResponse = null
	else:
		# Reached end of dialogue maybe
		end()
		return
	updateDialogue()

func prevState(id:StringName = "") -> void:
	if id:
		# Check for next state with same id
		for i in range(statePosition-1, -1, -1):
			var state = states[i]
			if state.id == id:
				statePosition = i
				linePosition = 0
				activeResponse = null
				updateDialogue()
				return
	elif statePosition > 0:
		statePosition -= 1
		linePosition = 0
		activeResponse = null
	else:
		return
	updateDialogue()
	
func gotoState(id:StringName, responseId:StringName = "") -> bool:
	# Check for first state with same id
	for i in range(states.size()):
		var state = states[i]
		if state.id == id:
			statePosition = i
			linePosition = 0
			activeResponse = null
			if responseId:
				return gotoResponse(responseId)
			landOnValidSection()
			updateDialogue()
			return true
	# Nothing had this name
	printerr("Tried to go to nonexistent state: ", id)
	end()
	return false
	
func repeatState() -> void:
	linePosition = 0
	activeResponse = null
	updateDialogue()
	
func skip() -> void:
	showingChoices = true
	updateDialogue()
			
func revealChoice(id:StringName) -> void:
	setChoiceHidden(id,false)
	
func hideChoice(id:StringName) -> void:
	setChoiceHidden(id,true)
	
func setChoiceHidden(id:StringName, hidden:bool = true) -> void:
	var state = states[statePosition]
	for choice in state.choices:
		if choice.id == id:
			choice.hidden = hidden
			proceedDialogue()
			return
	printerr("RevealChoice/HideChoice id ", id, " doesn't exist!")
	proceedDialogue()
			
func remapChoice(id:StringName, target:StringName) -> void:
	var state = states[statePosition]
	for choice in state.choices:
		if choice.id == id:
			choice.mapping = target
			proceedDialogue()
			return
	printerr("RemapChoice id ", id, " doesn't exist!")
	proceedDialogue()
			
func end() -> void:
	ended = true
	dialogue_ended.emit.call_deferred()

func getCurrentStateId() -> StringName:
	return states[statePosition].id
