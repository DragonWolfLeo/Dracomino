extends Node

signal dialogue_ended()
signal dialogue_waited_for_notification()
signal dialogue_started()
signal speaker_updated(speaker: String, expression: String)
signal dialogue_updated(line, choices)

var queuedNotifications:Array[String] = []
var yieldWaypointResourcePath:String = ""
	
class StashedDialogue:
	var dialogue:Dialogue
	func _init(_dialogue:Dialogue):
		dialogue = _dialogue

var dialogue:Dialogue
var dialogueStash:Array[StashedDialogue] = []

func clearHistory():
	for stackedDialogue in dialogueStash:
		stackedDialogue.dialogue.queue_free()
	dialogueStash.clear()
	FlagManager.clearTempFlag("yielded")
	
func initDialogue():
	if dialogue:
		dialogue.queue_free()
	dialogue = Dialogue.new()
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	dialogue.dialogue_updated.connect(dialogue_updated.emit)
	add_child(dialogue)

func stashCurrentDialogue():
	dialogueStash.append(StashedDialogue.new(dialogue))
	dialogue = null
	
func resumeStashedDialogue():
	if !dialogueStash.size(): return
	if dialogue:
		dialogue.queue_free()
	var stashable = dialogueStash.pop_back()
	dialogue = stashable.dialogue
	dialogue.proceedDialogue(true)
	
func setYieldWaypoint():
	if !dialogue: return
	if yieldWaypointResourcePath.length() and dialogueStash.size():
		# This would resume
		dialogue.end()
		FlagManager.clearTempFlag("yielded")
	else:
		# Set the waypoint!
		yieldWaypointResourcePath = dialogue.resourcePath
		
func yieldDialogue():
	if yieldWaypointResourcePath.length():
		FlagManager.setTempFlag("yielded")
		loadDialogue(yieldWaypointResourcePath, "", "", true)
	
func showNotification(string:String = ""):
	queuedNotifications.append(string)
	if dialogue and !dialogue.ended:
		return
	
	displayNextNotificiation()

func displayNextNotificiation() -> bool:
	if !queuedNotifications.size(): return false
	displayCustomDialogue(queuedNotifications.pop_front())
	return true

func displayCustomDialogue(rawText:String = "", jumpToState:StringName = "", jumpToResponse:StringName = ""):
	initDialogue()
	dialogue_started.emit()
	dialogue.loadDialogue(rawText, jumpToState, jumpToResponse)
	dialogue.name = "Notification"

func loadDialogue(script:Variant, jumpToState:StringName = "", jumpToResponse:StringName = "", isSubDialogue:bool = false):
	# Don't allow null
	if script == null:
		printerr("You tried to load a null script. Why would you do that?!")
		dialogue_ended.emit()
		return
	
	# Get the target script resource
	var scriptRes:Resource = (
		script if script is DialogueScript 
		else load(script) if (script as String).begins_with("res://")
		else load("res://dialogue/"+script+".script") 
	)
	if scriptRes == null:
		printerr("Error loading script ", script)
		scriptRes = load("res://dialogue/000_error.script")
	
	# Reset the dialogue system
	if dialogue and !dialogue.ended:
		await get_tree().process_frame
		if isSubDialogue:
			stashCurrentDialogue()
	else:
		clearHistory()
	initDialogue()
	dialogue_started.emit()
	
	dialogue.name = scriptRes.resource_path.get_file().get_basename()
	dialogue.resourcePath = scriptRes.resource_path

	# Load dialogue
	dialogue.loadDialogue(scriptRes.text, jumpToState, jumpToResponse)

func showPortrait(_option:String = ""):
	var args = _option.split(" ", false, 1)
	args.resize(2)
	updatePortrait.callv(args)

func hidePortrait():
	updatePortrait(null, "none")

func updatePortrait(speaker = "", expression:String = ""):
	expression = expression.to_lower()
	if expression == "none":
		speaker_updated.emit(null, expression)
		return

	speaker_updated.emit(speaker, expression)
	
func gotoResponse(id, fallback:StringName = ""):
	if !dialogue: return
	dialogue.gotoResponse(id, fallback)

var _waitingForNotification:bool = false
func waitForNotification():
	_waitingForNotification = true
	await dialogue_waited_for_notification
	_waitingForNotification = false

func closeDialogue():
	clearHistory()
	if dialogue:
		dialogue.ended = true
		dialogue.queue_free()
		dialogue = null
	if _waitingForNotification:
		dialogue_waited_for_notification.emit()
	else:
		dialogue_ended.emit()

func activateNavTagCommand(type:StringName, option:String): # Debug function
	if dialogue == null:
		print("Tried to activate navtag ", type, " while no dialogue is active")
		return
	type = type.to_upper()
	if Dialogue.NAVTAGS.has(type):
		var nt:Dialogue.NavTag = Dialogue.parseNavTagParams(option)
		nt.type = type
		dialogue.showingChoices = false
		dialogue.activateNavTag(nt)
	else:
		printerr("Tried to activate nonexistent navtag ", type)

### Events ###
func _on_dialogue_ended():
	if dialogueStash.size():
		resumeStashedDialogue()
		return

	var hasNotification = displayNextNotificiation()
	if !hasNotification:
		closeDialogue()
		
