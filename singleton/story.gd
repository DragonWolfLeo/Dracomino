## Story-related constants and classes
extends Node

# === Story mode definitions ===
var CAMPAIGNS:Dictionary[StringName, Campaign] = {
	classic = Campaign.new("Dragon Hoard"),
	story_mini_home = Campaign.new("Home Sweet Home", [
		Act.new({
			"id": "dragonlair",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.dragonlair,
			"triggers": [
				# Mini moves into the cave; Nuggets are revealed after they spill them
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_start")),
				# Mini picks up first nugget
				EventTrigger.ObjectCollected("nugget", 1)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_nugget_1")),
				# Mini clears first line
				EventTrigger.LinesCleared(1)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_lineclear_1")),
				# Mini reaches the halfway point; Webs are placed after discovering them
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_halflineprogress")),
				# Mini collects all nuggets
				EventTrigger.ObjectRatioCollected("nugget", 1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_allnuggets")),
				# Mini touches a web and reacts
				EventTrigger.OnSignal("boardObject_web_touched")
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_ontouchweb"))
					.setCondition("!storycontext_foundweb"),
				# Mini clears all webs
				EventTrigger.ObjectRatioCollected("web", 1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_allwebs")),
				# Mini clears all lines; Move on to next act
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "dragonlair_clear")),
			],
		}),
		Act.new({
			"id": "spookywoods",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.spookywoods,
			"triggers": [
				# Mini runs into the spooky woods
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_start")),
				# Mini defeats first ghost
				EventTrigger.ObjectCollected("ghost", 1)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_ghost_1")),
				# Mini sees phantom
				EventTrigger.LineRatioCleared(0.3)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_1")),
				# Phantom encounter
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_2")),
				# Phantom encounter
				EventTrigger.LineRatioCleared(0.8)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_lineprogress_3")),
				# Phantom boss starts
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spookywoods_clear")),
			],
		}),
		Act.new({
			"id": "phantom",
			"type": Act.TYPE.boss,
			"area": Act.AREA.spookywoods,
			"triggers": [
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Spawn("phantom")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.3)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "phantom_progress_1")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.5)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "phantom_progress_2")),
				# Boss dialogue
				EventTrigger.LineRatioCleared(0.8)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "phantom_progress_3")),
				# Boss finish
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "phantom_clear")),
			],
		}),
		Act.new({
			"id": "riverside",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.riverside,
			"triggers": [
				# Mini and Mega enter Riverside and see fish
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "riverside_start")),
				# Mini fishes some treasure and gets an item
				EventTrigger.ObjectCollected("treasure", 1)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "riverside_treasure_1")),
				# Mini get their first fish and decide on a goal
				EventTrigger.ObjectCollected("fish", 1)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "riverside_fish_1")),
				# Mini reach the end of act and check if they have enough fish; Complete the act if so
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "riverside_alllines")),
				# Complete the act if reached the end with enough fish
				EventTrigger.ItemReceived("fish", 8)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "riverside_clear"))
					.setCondition("storycontext_reachedriversideend"),
				# Scripted gimmics
				EventTrigger.LinesCleared(2)
					.setEffect(TriggerEffect.Effect("fishing", 1)),
				EventTrigger.LinesCleared(4)
					.setEffect(TriggerEffect.Effect("water_trap", 2)),
				EventTrigger.LinesCleared(10)
					.setEffect(TriggerEffect.Effect("riptide_trap", 8)),
				EventTrigger.LinesCleared(13)
					.setEffect(TriggerEffect.Effect("fishing", 1)),
				EventTrigger.LinesCleared(16)
					.setEffect(TriggerEffect.Effect("water_trap", 2)),
			],
		}),
		Act.new({
			"id": "spidernest",
			"type": Act.TYPE.puzzle,
			"area": Act.AREA.spidernest,
			"triggers": [
				# Mini and Mega approach the spider nest
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spidernest_start")),
				# Mega begins using mana to zap spiders
				EventTrigger.LinesCleared(2)
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spidernest_lineclear_1")),
				# Go to the next act (boss)
				EventTrigger.LineRatioCleared(1.0)
					.setEffect(TriggerEffect.NextAct()),
			],
		}),
		Act.new({
			"id": "spiderboss",
			"type": Act.TYPE.boss,
			"area": Act.AREA.spidernest,
			"triggers": [
				EventTrigger.ActStarted()
					.setEffect(TriggerEffect.Spawn("spiderboss")),
				EventTrigger.OnSignal("spiderboss_defeated")
					.setEffect(TriggerEffect.Cutscene("story_mini_home", "spiderboss_clear")),
			],
		}),
	]),
}

const APWORLD_SLOTDATA:Dictionary[StringName, Array] = { # TODO: Temporary
	story_mini_home = [
		{
			"id": "dragonlair",
			"name": "Dragon Lair",
			"lines": 20,
		},
		{
			"id": "spookywoods",
			"name": "Spooky Woods",
			"lines": 20,
		},
		{
			"id": "phantom",
			"name": "Boss - Phantom",
			"lines": 10,
		},
		{
			"id": "riverside",
			"name": "Riverside",
			"lines": 20,
		},
		{
			"id": "spidernest",
			"name": "Spider Nest",
			"lines": 20,
		},
		{
			"id": "spiderboss",
			"name": "Boss - Spider Queen",
			"lines": 10,
		},
	]
}


class Campaign:
	var prettyName:String
	var acts:Array[Act] = []
	func _init(_prettyName:String = "", _acts:Array[Act] = []) -> void:
		prettyName = _prettyName
		acts.append_array(_acts)

class Act:
	var lines:int
	var areaName:StringName
	var type:StringName
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
		lines = int(data.get("lines", 0))
		type = str(data.get("type", ""))

class EventTrigger:
	var effect:TriggerEffect
	var condition:String
	var amount:int

	static func ActStarted() -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func LineReached(_line:int) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func LinesCleared(_amount:int) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func LineRatioCleared(_ratio:float) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func ObjectCollected(_objectName:StringName = &"", _amount:int = 1) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func ObjectRatioCollected(_objectName:StringName = &"", _ratio:float = 1.0) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func ItemReceived(_itemName:StringName, _amount:int = 1) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func ItemRatioReceived(_itemName:StringName, _ratio:float = 1.0) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	static func OnSignal(_signalName:StringName) -> EventTrigger:
		var trigger:EventTrigger = EventTrigger.new()
		return trigger

	func setEffect(_effect:TriggerEffect) -> EventTrigger:
		self.effect = _effect
		return self

	func setCondition(_condition:String) -> EventTrigger:
		self.condition = _condition
		return self


class TriggerEffect:
	var type:StringName
	const TYPE:Dictionary[StringName, StringName] = {
		cutscene = "cutscene",
		effect = "effect",
	}
	static func Cutscene(dialogue:StringName, response:StringName = &"") -> TriggerEffect:
		var fx:TriggerEffect = TriggerEffect.new()
		return fx

	static func Effect(effect:StringName, duration:int = 0) -> TriggerEffect:
		var fx:TriggerEffect = TriggerEffect.new()
		return fx

	static func Spawn(entity:StringName) -> TriggerEffect:
		var fx:TriggerEffect = TriggerEffect.new()
		return fx

	static func NextAct() -> TriggerEffect:
		var fx:TriggerEffect = TriggerEffect.new()
		return fx

