@tool
extends EditorSyntaxHighlighter
class_name DialogueEditorSyntaxHighlighter

var commentColor:Color = Color("52f55aa7") # Comment color
var tagColor:Color = Color("ff7085") # Keyword color
var navtagColor:Color = Color("ff8ccc") # Control flow color
var commandColor:Color = Color("57b3ff") # Function color
var dialogueColor:Color = Color("ffeda1") # String color
var actionColor:Color = Color("cdcfd2") # Text color
var speakerColor:Color = Color("42ffc2") # Base type color
var expressionColor:Color = Color("bce0ff") # Member variable color
var symbolColor:Color = Color("abc9ff") # Symbol color

enum TAGS {
	STATE,
	CHOICE,
	PROMPT,
	JUMP,
	RESPONSE,
	IF,
	ELSE,
	ALWAYS,
}
enum NAVTAGS {
	REVEALCHOICE,
	HIDECHOICE,
	REMAPCHOICE,
	NEXTSTATE,
	PREVSTATE,
	GOTOSTATE,
	REPEATSTATE,
	SKIP,
	END,
	RESET,
}

func _get_name() -> String:
	return "Dialogue"

func _get_supported_languages() -> PackedStringArray:
	return ["TextFile", "DialogueScript"]

func matchEditorSettings():
	var settings = EditorInterface.get_editor_settings()
	commentColor = settings.get("text_editor/theme/highlighting/comment_color")
	tagColor = settings.get("text_editor/theme/highlighting/keyword_color")
	navtagColor = settings.get("text_editor/theme/highlighting/control_flow_keyword_color")
	commandColor = settings.get("text_editor/theme/highlighting/function_color")
	dialogueColor = settings.get("text_editor/theme/highlighting/string_color")
	actionColor = settings.get("text_editor/theme/highlighting/text_color")
	speakerColor = settings.get("text_editor/theme/highlighting/base_type_color")
	expressionColor = settings.get("text_editor/theme/highlighting/member_variable_color")
	symbolColor = settings.get("text_editor/theme/highlighting/symbol_color")

func readAtUntil(index, until, string:String, includeEnd = false) -> String:
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
	return ""

func positionUntil(index, until:String, string:String) -> int:
	var untilFirstChar = until[0]
	for i in range(index, string.length()):
		var c = string[i]
		if c == untilFirstChar:
			var pat = string.substr(i, until.length())
			if pat == until:
				return i
	return -1

func _get_line_syntax_highlighting(lineNum: int) -> Dictionary:
	var te:TextEdit = get_text_edit()
	var line:String = te.get_line(lineNum)	
	var sh:Dictionary = {
		"speaker": false,
		"expression": false,
		"mainColor": speakerColor,
		"isContinued": false,
		0: null, # This needs to be before all the other numbers
	}

	# Check if this is an empty line and then just get whether its continued or not
	if line.strip_edges().is_empty():
		if lineNum > 0:
			var prev = _get_line_syntax_highlighting(lineNum - 1)
			sh.speaker = prev.get("speaker", false)
			sh.expression = prev.get("expression", false)
			sh.mainColor = prev.get("mainColor", sh.mainColor)
			sh.isContinued = prev.get("isContinued", false)
		return sh

	# Check if this is a continuation
	var isContinuedFromPrevious:bool = false
	if lineNum > 0:
		var prev = _get_line_syntax_highlighting(lineNum - 1)
		
		isContinuedFromPrevious = prev.get("isContinued", false) or line[0].strip_edges().is_empty()

		if isContinuedFromPrevious:	
			sh.speaker = prev.get("speaker", false)
			sh.expression = prev.get("expression", false)
			sh.mainColor = prev.get("mainColor", speakerColor)
			sh[0] = {color = sh.mainColor}

	var i:int = 0
	var colonIndex:int = 0
	if not isContinuedFromPrevious:
		colonIndex = positionUntil(0, ":", line)
		colonIndex = colonIndex if colonIndex > 0 else 0
		if colonIndex > 0:
			sh[0] = {color = sh.mainColor}
		else:
			sh.mainColor = dialogueColor
	
	while i < line.length():
		var c:String = line[i]
		match c:
			"(":
				if !sh.expression and !sh.speaker:
					var pos = positionUntil(i+1, ")", line)
					if pos > 0:
						sh[i] = {color = symbolColor}
						sh[i+1] = {color = expressionColor}
						sh.expression = true
						i = pos
						sh[i] = {color = symbolColor}
						sh[i+1] = {color = sh.mainColor}
			":":
				if !sh.speaker:
					sh.speaker = true
					sh.mainColor = dialogueColor
					sh[i] = {color = symbolColor}
					sh[i+1] = {color = sh.mainColor}
			"[":
				var raw = readAtUntil(i+1, "]", line, false)
				var tag = raw.strip_edges() if raw else ""
				if tag.length():
					sh[i] = {color = symbolColor}
					var params = tag.split(" ", false, 1)
					params[0] = params[0].to_upper()
					params.resize(1)
					if params[0] in TAGS:
						sh[i+1] = {color = tagColor}
					elif params[0] in NAVTAGS:
						sh[i+1] = {color = navtagColor}
					else:
						sh[i+1] = {color = commandColor}
					i += raw.length() + 1
					sh[i] = {color = symbolColor}		
					sh[i+1] = {color = sh.mainColor}
			"{":
				if sh.speaker or colonIndex <= 0:
					var pos = positionUntil(i+1, "}", line)
					if pos > 0:
						sh[i] = {color = symbolColor}
						sh[i+1] = {color = expressionColor}
						i = pos
						sh[i] = {color = symbolColor}
						sh[i+1] = {color = sh.mainColor}
			# Comments
			"/":
				if i+1 < line.length():
					match line[i+1]:
						"/": 
							sh[i] = {color = commentColor}
							break
						"*": 
							var pos = positionUntil(i+2, "*/", line)
							if pos >= 0:
								sh[i] = {color = commentColor}
								i = pos + 1		
								sh[i+1] = {color = sh.mainColor}
			"*":
				if i+1 < line.length():
					match line[i+1]:
						"*": 
							var pos = positionUntil(i+2, "**", line)
							if pos >= 0:
								sh[i] = {color = actionColor}
								i = pos + 1		
								sh[i+1] = {color = sh.mainColor}
			# Continuation
			"\\":
				if i+1 < line.length() and line[i+1] == "\\":
					i += 1
				else:
					sh.isContinued = true
					sh[i] = {color = symbolColor}
					while i+1 < line.length():
						if line[i+1].strip_edges().length():
							sh.isContinued = false
							sh[i+1] = {color = sh.mainColor}
							break
						i += 1
		i += 1

	# Look forward if there is a indented continuation so we can decide to make this speaker color
	if not isContinuedFromPrevious and sh.get(0) == null:
		var lineCount = te.get_line_count()
		var nextLineNum = lineNum + 1
		var nextLineIsContinuation:bool = sh.isContinued
		while !nextLineIsContinuation and nextLineNum < lineCount:
			var nextLine = te.get_line(nextLineNum)
			if nextLine.strip_edges().is_empty():
				nextLineNum += 1
			else:
				nextLineIsContinuation = nextLine[0].strip_edges().is_empty()
				break
		if nextLineIsContinuation:
			sh[0] = {color = speakerColor}

	return sh