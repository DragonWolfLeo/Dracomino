extends Node

signal command_error()

class Command:
	signal command_activated()
	signal bound_node_tree_exiting()
	var fn:Callable
	var invisible:bool = false # Invisible commands allow the dialogue to proceed if there's no other content to show
	var deprecated:bool = false
	var argHint:String = ""
	func _init(_fn:Callable, _invisible:bool = false):
		fn = _fn
		invisible = _invisible
	func setDeprecated(_deprecated:bool = true) -> Command:
		deprecated = _deprecated
		return self
	func setInvisible(_invisible:bool = true) -> Command:
		invisible = _invisible
		return self
	func setArgHint(_argHint:String = "") -> Command:
		argHint = _argHint
		return self
	func bind(node:Node) -> Command: ## Bind a command to a node so it clears when the node is freed
		node.tree_exiting.connect(bound_node_tree_exiting.emit)
		return self
	func disconnectSignals() -> void: ## Disconnect signals for clean up
		for s:Signal in [command_activated, bound_node_tree_exiting] as Array[Signal]:
			for dict:Dictionary in s.get_connections():
				(dict["signal"] as Signal).disconnect(dict["callable"] as Callable)

var COMMANDS:Dictionary[StringName, Command] = {}

func _noop(_option): pass

func _ready():	
	const DESC := {
		SETFLAG = "flag value(optional)",
		COUNT = "flag key(non-number or literal \"threshold\"; optional) amount(number)=1 add(literal \"add\"; optional)",
		LOADDIALOGUE = "file state(optional) response(optional)",
	}
	# Debug
	addCommand("PRINT", print, true)
	addCommand("CUSTOMDIALOGUE", DialogueManager.displayCustomDialogue).setArgHint("dialogue")
	# # Overlay stuff
	addCommand("SHOWIMAGE", Overlay.showImageByName).setArgHint("image")
	addCommand("HIDEIMAGE", Overlay.hideImage.bind(false).unbind(1), true)
	addCommand("SHOWOBJECT", Overlay.showObjectByName).setArgHint("scene")
	addCommand("HIDEOBJECT", Overlay.hideObject.bind(false).unbind(1), true)
	addCommand("FADEIN", Overlay.doFadeIn.unbind(1), true)
	addCommand("FADEOUT", Overlay.doFadeOut.unbind(1), true)
	addCommand("FADEOUTINVISIBLE", Overlay.doFadeOut.unbind(1), true)
	addCommand("SHOWCUTSCENE", Overlay.showCutsceneByName).setArgHint("cutscene")
	addCommand("HIDECUTSCENE", Overlay.hideCutscene.unbind(1), true)
	addCommand("ANNOUNCE", Overlay.queueAnnouncement, true).setArgHint("message")
	# Default flag setting (world)
	addCommand("SETFLAG", FlagManager.HANDLERS.WORLD.setFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARFLAG", FlagManager.HANDLERS.WORLD.clearFlag, true).setArgHint("flag")
	addCommand("COUNT", FlagManager.HANDLERS.WORLD.count, true).setArgHint(DESC.COUNT)
	# Main flag setting
	addCommand("SETMAINFLAG", FlagManager.HANDLERS.MAIN.setFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARMAINFLAG", FlagManager.HANDLERS.MAIN.clearFlag, true).setArgHint("flag")
	addCommand("MAINCOUNT", FlagManager.HANDLERS.MAIN.count, true).setArgHint(DESC.COUNT)
	# Level flag setting
	addCommand("SETLEVELFLAG", FlagManager.HANDLERS.LEVEL.setFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARLEVELFLAG", FlagManager.HANDLERS.LEVEL.clearFlag, true).setArgHint("flag")
	addCommand("LEVELCOUNT", FlagManager.HANDLERS.LEVEL.count, true).setArgHint(DESC.COUNT)
	# World flag setting
	addCommand("SETWORLDFLAG", FlagManager.HANDLERS.WORLD.setFlag, true).setArgHint(DESC.SETFLAG).setDeprecated()
	addCommand("CLEARWORLDFLAG", FlagManager.HANDLERS.WORLD.clearFlag, true).setArgHint("flag").setDeprecated()
	addCommand("WORLDCOUNT", FlagManager.HANDLERS.WORLD.count, true).setArgHint(DESC.COUNT).setDeprecated()
	# Dialogue system stuff
	addCommand("LOADDIALOGUE", func(_option:String):
		var args = _option.split(" ", false, 2); args.resize(3); DialogueManager.loadDialogue.call_deferred.bind(false).callv(args)
		).setArgHint(DESC.LOADDIALOGUE)
	addCommand("SUBDIALOGUE", func(_option:String):
		var args = _option.split(" ", false, 2); args.resize(3); DialogueManager.loadDialogue.call_deferred.bind(true).callv(args)
		).setArgHint(DESC.LOADDIALOGUE)
	addCommand("CLEARHISTORY", DialogueManager.clearHistory.unbind(1), true)
	addCommand("YIELD", DialogueManager.yieldDialogue.unbind(1))
	addCommand("YIELDWAYPOINT", DialogueManager.setYieldWaypoint.unbind(1), true)
	addCommand("SHOWPORTRAIT", DialogueManager.showPortrait, true).setArgHint("speaker expression")
	addCommand("HIDEPORTRAIT", DialogueManager.hidePortrait.unbind(1), true)
	addSignalCommand("WAIT")
	# Emit from signal bus
	addCommand("EMIT", func(_option:String): var args = _option.split(" ", false, 1); SignalBus.getSignal.callv(args).emit(), true).setArgHint("key(optional) flag")

func addCommand(id:StringName, fnWithOptionalArgument: Callable, invisible:bool = false, force:bool = false) -> Command:
	id = id.to_upper()
	if COMMANDS.has(id):
		if force:
			removeCommand(id, COMMANDS[id])
		else:
			printerr("Error adding command {id}: id already exists and is not forced!".format({id = id}))
			return null
	COMMANDS[id] = Command.new(fnWithOptionalArgument, invisible)
	COMMANDS[id].bound_node_tree_exiting.connect(removeCommand.bind(id, COMMANDS[id]))
	return COMMANDS[id]

func addSignalCommand(id:String, invisible:bool = false, force:bool = false) -> Command:
	return addCommand(id, _noop, invisible, force)

func removeCommand(id:StringName, command:Command) -> void:
	if COMMANDS.get(id) == command:
		COMMANDS.erase(id)
		command.disconnectSignals()
	else:
		if COMMANDS.has(id):
			printerr("CommandManager.removeCommand error: command {id} is different from provided command.".format({id=id}))
		else:
			print("CommandManager.removeCommand warning: command {id} doesn't exist".format({id=id}))

func getCommand(id:StringName)->Command:
	return COMMANDS.get(id)

func getCommandSignal(id:StringName) -> Signal:
	assert(id == id.to_upper())
	var com = getCommand(id)
	if com: return com.command_activated
	printerr("Cannot get signal from invalid command {id}".format({id=id}))
	return command_error
	
func activateCommand(id:StringName, option:String = ""):
	assert(id == id.to_upper())
	var entry:Command = COMMANDS.get(id) as Command
	if entry:
		option = option.strip_edges()
		if entry.get("fn") is Callable:
			if entry.fn.get_argument_count() == 0:
				entry.fn.call()
			else: 
				entry.fn.call(option)
			if Config.debugMode and entry.deprecated: print("Command {id} is deprecated!".format({id=id}))
			entry.command_activated.emit()
		else:
			printerr("Command does not have key \"fn\" as Callable: ", id)
	else:
		printerr("Tried to call nonexistent command ", id)
