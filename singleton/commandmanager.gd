extends Node

signal command_error()

class Command:
	signal command_activated
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
	# Global flag setting
	addCommand("SETFLAG", FlagManager.setFlag, true).setArgHint(DESC.SETFLAG)
	# addCommand("SETFLAGTOMORROW", FlagManager.queueFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARFLAG", FlagManager.clearFlag, true).setArgHint("flag")
	addCommand("COUNT", FlagManager.count, true).setArgHint(DESC.COUNT)
	# Level flag setting
	addCommand("SETLEVELFLAG", FlagManager.HANDLERS.LEVEL.setFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARLEVELFLAG", FlagManager.HANDLERS.LEVEL.clearFlag, true).setArgHint("flag")
	addCommand("LEVELCOUNT", FlagManager.HANDLERS.LEVEL.count, true).setArgHint(DESC.COUNT)
	# World flag setting
	addCommand("SETWORLDFLAG", FlagManager.HANDLERS.WORLD.setFlag, true).setArgHint(DESC.SETFLAG)
	addCommand("CLEARWORLDFLAG", FlagManager.HANDLERS.WORLD.clearFlag, true).setArgHint("flag")
	addCommand("WORLDCOUNT", FlagManager.HANDLERS.WORLD.count, true).setArgHint(DESC.COUNT)
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
	addCommand("EMIT", SignalBus.signal_self.emit, true).setArgHint("signal")

func addCommand(id:StringName, fnWithExactlyOneArgument: Callable, invisible:bool = false, force:bool = false)->Command:
	id = id.to_upper()
	if !force and COMMANDS.has(id):
		printerr("Error adding command {id}: id already exists and is not forced!".format({id = id}))
		return null
	
	COMMANDS[id] = Command.new(fnWithExactlyOneArgument, invisible)
	return COMMANDS[id]

func addSignalCommand(id:String, invisible:bool = false, force:bool = false)->Command:
	return addCommand(id, _noop, invisible, force)
	
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
			entry.fn.call(option)
			if Config.debugMode and entry.deprecated: print("Command {id} is deprecated!".format({id=id}))
			entry.command_activated.emit()
		else:
			printerr("Command does not have key \"fn\" as Callable: ", id)
	else:
		printerr("Tried to call nonexistent command ", id)
