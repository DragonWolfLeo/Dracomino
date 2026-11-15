## Story-related constants and classes
extends Node

static var effectHandler:EffectHandler

# === Virtuals ===
func _init() -> void:
	# Make an effect handler here
	if effectHandler:
		effectHandler.queue_free()
	effectHandler = EffectHandler.new()
	add_child(effectHandler)

# === Story mode definitions ===
@onready var CHAPTERS:Dictionary[StringName, Chapter] = {
	classic = Chapter.new("Dragon Hoard"),
	story_mini_home = Chapter.new("Home Sweet Home", [
		Act.new({
			"id": "dragonlair",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.dragonlair,
			"triggers": [
				# Mini moves into the cave; Nuggets are revealed after they spill them
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_start")),
				# Mini picks up first nugget
				EventTrigger.ObjectCollected("nugget")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_nugget_1")),
				# Mini clears first line
				EventTrigger.LinesCleared(1)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_lineclear_1")),
				# Mini reaches the halfway point; Webs are placed after discovering them
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_halflineprogress"))
					.setCondition("!storycontext_clearedallwebs")
					.setRepeatable(),
				# Mini collects all nuggets
				EventTrigger.ObjectsAllCollected("nugget")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_allnuggets")),
				# Mini touches a web and reacts
				EventTrigger.OnSignal("boardObject_web_touched")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_ontouchweb"))
					.setCondition("!storycontext_touchedweb"),
				# Mini clears all webs
				EventTrigger.ObjectsAllCollected("web")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_allwebs"))
					.setCondition("storycontext_foundweb"),
				# Mini clears all lines; Move on to next act
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "dragonlair_clear")),
			],
		}),
		Act.new({
			"id": "spookywoods",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.spookywoods,
			"triggers": [
				# Mini runs into the spooky woods
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_start")),
				# Mini defeats first ghost
				EventTrigger.ObjectCollected("ghost")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_ghost_1")),
				# Mini sees phantom
				EventTrigger.LineRatioCleared(0.3)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_1")),
				# Phantom encounter
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_2")),
				# Phantom encounter
				EventTrigger.LineRatioCleared(0.8)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_3")),
				# Phantom boss starts
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spookywoods_clear")),
			],
		}),
		Act.new({
			"id": "phantom",
			"type": Act.TYPE.boss,
			"area": Act.AREA.spookywoods,
			"triggers": [
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Spawn("phantom")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.3)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "phantom_progress_1")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "phantom_progress_2")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.8)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "phantom_progress_3")),
				# Boss finish
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "phantom_clear")),
			],
		}),
		Act.new({
			"id": "riverside",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.riverside,
			"triggers": [
				# Mini and Mega enter Riverside and see fish
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "riverside_start")),
				# Mini fishes some treasure and gets an item
				EventTrigger.ObjectCollected("treasure")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "riverside_treasure_1")),
				# Mini get their first fish and decide on a goal
				EventTrigger.ObjectCollected("fish")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "riverside_fish_1")),
				# Mini reach the end of act and check if they have enough fish; Complete the act if so
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "riverside_alllines")),
				# Complete the act if reached the end with enough fish
				EventTrigger.ItemReceived("fish", 8)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "riverside_clear"))
					.setCondition("storycontext_reachedriversideend"),
				# Scripted gimmics
				EventTrigger.LinesCleared(2)
					.setEffect(TriggeredEffect.HandlerEffect("fishing")),
				EventTrigger.LinesCleared(4)
					.setEffect(TriggeredEffect.LineTickedEffect("overlay_water", 4)).setRepeatable(),
				EventTrigger.LinesCleared(10)
					.setEffect(TriggeredEffect.LineTickedEffect("effect_riptide", 8)).setRepeatable(),
				EventTrigger.LinesCleared(13)
					.setEffect(TriggeredEffect.HandlerEffect("fishing")),
				EventTrigger.LinesCleared(16)
					.setEffect(TriggeredEffect.LineTickedEffect("overlay_water", 4)).setRepeatable(),
			],
		}),
		Act.new({
			"id": "spidernest",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.spidernest,
			"triggers": [
				# Mini and Mega approach the spider nest
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spidernest_start")),
				# Mega begins using mana to zap spiders
				EventTrigger.LinesCleared(2)
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spidernest_lineclear_1")),
				# Go to the next act (boss)
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggeredEffect.NextAct()),
			],
		}),
		Act.new({
			"id": "spiderboss",
			"type": Act.TYPE.boss,
			"area": Act.AREA.spidernest,
			"triggers": [
				EventTrigger.ActStarted()
					.setEffect(TriggeredEffect.Spawn("spiderboss")),
				EventTrigger.OnSignal("spiderboss_defeated")
					.setEffect(TriggeredEffect.Cutscene("story_mini_home", "spiderboss_clear")),
			],
		}),
	]),
}

const APWORLD_SLOTDATA:Dictionary[StringName, Variant] = { # TODO: Temporary
	acts = [
		{
			"chapter": "story_mini_home",
			"id": "dragonlair",
			"name": "Dragon Lair",
			"lines": 20,
		},
		{
			"chapter": "story_mini_home",
			"id": "spookywoods",
			"name": "Spooky Woods",
			"lines": 20,
		},
		{
			"chapter": "story_mini_home",
			"id": "phantom",
			"name": "Boss - Phantom",
			"lines": 10,
			"continuation": true,
		},
		{
			"chapter": "story_mini_home",
			"id": "riverside",
			"name": "Riverside",
			"lines": 20,
		},
		{
			"chapter": "story_mini_home",
			"id": "spidernest",
			"name": "Spider Nest",
			"lines": 20,
		},
		{
			"chapter": "story_mini_home",
			"id": "spiderboss",
			"name": "Boss - Spider Queen",
			"lines": 10,
			"continuation": true,
		},
	],
	chapter_names = {
		story_mini_home = "Home Sweet Home",
	},
	requirements = [],
}


class Chapter:
	var prettyName:String
	var acts:Dictionary[StringName, Act] = {}
	func _init(_prettyName:String = "", _acts:Array[Act] = []) -> void:
		prettyName = _prettyName
		for act:Act in _acts:
			acts[act.id] = act

class Act:
	var id:StringName
	var lines:int
	var areaName:StringName
	var type:StringName
	var triggers:Array[EventTrigger] = []
	const TYPE:Dictionary[StringName, StringName] = {
		puzzle = "puzzle",
		boss = "boss",
		freeroam = "freeroam",
	}
	const AREA:Dictionary[StringName, StringName] = {
		dragonlair = "dragonlair",
		spookywoods = "spookywoods",
		riverside = "riverside",
		spidernest = "spidernest",
	}
	const AREA_PRETTY_NAME:Dictionary[StringName, StringName] = {
		dragonlair = "Dragon Lair",
		spookywoods = "Spooky Woods",
		riverside = "Riverside",
		spidernest = "Spider Nest",
	}

	func _init(data:Dictionary[StringName, Variant] = {}) -> void:
		id = str(data.get("id", ""))
		lines = int(data.get("lines", 0))
		type = str(data.get("type", ""))
		triggers.append_array(data.get("triggers", []))

class EventTrigger:
	var effect:EffectHandler.Effect
	var repeatable:bool = false
	var condition:String

	static func ActStarted() -> EventTrigger:
		return LineReachedEventTrigger.new(0)

	static func LineReached(_line:int) -> EventTrigger:
		return LineReachedEventTrigger.new(_line)

	static func LinesCleared(_amount:int) -> EventTrigger:
		return LinesClearedEventTrigger.new(_amount)

	static func LineRatioCleared(_ratio:float) -> EventTrigger:
		return LineRatioClearedEventTrigger.new(_ratio)

	static func ObjectCollected(_objectName:StringName = &"") -> EventTrigger:
		return ObjectCollectedEventTrigger.new(_objectName)

	static func ObjectsAllCollected(_objectName:StringName = &"") -> EventTrigger:
		return ObjectsAllCollectedEventTrigger.new(_objectName)

	static func ItemReceived(_itemName:StringName, _amount:int = 1) -> EventTrigger:
		return ItemReceivedEventTrigger.new(_itemName, _amount)

	static func OnSignal(_signalKey:StringName, _signalFlag:StringName = "") -> EventTrigger:
		return OnSignalEventTrigger.new(SignalBus.getSignal(_signalKey, _signalFlag))

	func setEffect(_effect:EffectHandler.Effect) -> EventTrigger:
		effect = _effect
		return self

	func setRepeatable(_repeatable:bool = true) -> EventTrigger:
		repeatable = _repeatable
		return self

	func setCondition(_condition:String) -> EventTrigger:
		condition = _condition
		return self

class LineReachedEventTrigger extends EventTrigger:
	var line:int
	func _init(_line:int) -> void:
		line = _line

class LinesClearedEventTrigger extends EventTrigger:
	var amount:int
	func _init(_amount:int) -> void:
		amount = _amount

class LineRatioClearedEventTrigger extends EventTrigger:
	var ratio:float
	func _init(_ratio:float) -> void:
		ratio = _ratio

class ObjectCollectedEventTrigger extends EventTrigger:
	var objectName:StringName
	func _init(_objectName:StringName) -> void:
		objectName = _objectName

class ObjectsAllCollectedEventTrigger extends EventTrigger:
	var objectName:StringName
	func _init(_objectName:StringName) -> void:
		objectName = _objectName

class ItemReceivedEventTrigger extends EventTrigger:
	var itemName:StringName
	var amount:int
	func _init(_itemName:StringName, _amount:int) -> void:
		itemName = _itemName
		amount = _amount

class OnSignalEventTrigger extends EventTrigger:
	var sig:Signal
	func _init(_sig:Signal) -> void:
		sig = _sig

class TriggeredEffect extends EffectHandler.Effect:
	var type:StringName
	const TYPE:Dictionary[StringName, StringName] = {
		cutscene = "cutscene",
		effect = "effect",
	}
	# === Constructors ===
	## Play a dialogue
	static func Cutscene(dialogue:StringName, jumpToState:StringName = &"") -> EffectHandler.Effect:
		return EffectHandler.Effect.new(_loadDialogue.bind(dialogue, jumpToState)).setCanTriggerFn(_canLoadNewDialogue)

	## Start an effect that lasts for a specified amount of lines
	static func LineTickedEffect(flag:StringName, duration:int = 0) -> EffectHandler.BoardEffect:
		return EffectHandler.BoardEffect.new(_board_activateLineTickedEffect.call_deferred.bind(flag, duration))

	## Use a pre-defined effect from EffectHandler
	static func HandlerEffect(effectName:StringName) -> EffectHandler.Effect:
		return Story.effectHandler.EFFECTS.get(effectName)

	## Spawn an entity
	static func Spawn(entity:StringName) -> EffectHandler.Effect:
		return TriggeredEffect.new(print.bind("TODO: Spawn a %s here!"%entity))

	## Go to the next act
	static func NextAct() -> EffectHandler.Effect:
		return TriggeredEffect.new(print.bind("TODO: Go to next act"))

	# === Private Effect Functions ===
	static func _loadDialogue(dialogue:Variant, jumpToState:StringName = &"") -> void:
		DialogueManager.loadDialogue(dialogue, jumpToState)

	static func _canLoadNewDialogue() -> bool:
		return DialogueManager.dialogue == null

	static func _board_activateLineTickedEffect(board:Board, flag:StringName, duration:float = 1.0) -> void:
		print("Activated {flag} for {duration} lines.".format([flag,duration]))
		var ae:ActiveEffect = ActiveEffect.instantiateEffect(flag, duration, false)
		var parent:Node = (board.effectHandler as Node) if board.effectHandler else (board as Node)
		parent.add_child(ae)
		board.line_cleared.connect(ae.tickDuration.bind(1, false).unbind(1))
