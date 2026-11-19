class_name DracominoHandler extends Node

static var collectedItems:Array[StateItem] = []
var missingLocations:Dictionary[int, bool] = {}
var checkedLocations:Dictionary[int, bool] = {}
var victory:bool = false
var currentIndex:int = 0
var collectedAbilities:Dictionary[int, int] = {}
var gotLines:Dictionary[int, bool] = {}
var allLineLocations:Array[int] = []
var missingPickups:Array[int] = []
var boardObjects:Dictionary[int, StateBoardObject] = {}
var lineMappings:Dictionary[int, int] = {}
var missingLines:Dictionary[int, bool] = {}
var id_to_line:Dictionary[int, int] = {}
var id_to_boardObject:Dictionary[int, StateBoardObject] = {}
var hintedRotateAbilities:Dictionary[int, StateItem] = {}
var seedIsValid:bool = false
var goal:int = -1:
	set(value):
		if goal == value: return
		goal = value
		goal_updated.emit(goal)
		if seedFlagHolder:
			seedFlagHolder.setFlag("goal", value)
var slotContextHash:int:
	set(value):
		if slotContextHash == value:
			return
		slotContextHash = value
		slotContextHash_updated.emit(slotContextHash)
var campaign:CampaignContext:
	set(value):
		if campaign == value:
			return
		campaign = value
		campaign_changed.emit(campaign)
var seedFlagHolder:FlagHolder
var retroFlagHolder:FlagHolder
var effectHandler:EffectHandler

var color_random:RandomNumberGenerator = RandomNumberGenerator.new()
var color_randomSaveState:int = color_random.state
var rotate_random:RandomNumberGenerator = RandomNumberGenerator.new()
var rotate_randomSaveState:int = rotate_random.state

var isJustConnected:bool = false
var VERSION_WARNING_DIALOG_SCENE:PackedScene = load("res://ui/versionwarning_dialog.tscn")
var DELAYED_EFFECT_CONTEXT_DURATION:float = 0.5 # Shorter than board's

var LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT:int = 8 ## For death context
var _canUseDeathContext_NO_ROTATE:bool = false ## For death context
var _energySendBuffer:int = 0 ## Energy to send to server when reconnecting
var _effectBuffer:Array[StateItem] = [] ## Next traps to apply to next pieces

signal lineMappings_updated(mappings:Dictionary[int, int])
signal gotLines_updated(_gotLines:Dictionary[int, bool])
signal missingLines_updated(locs:Dictionary[int, bool])
signal notification_signal(notif:String, color:Color, force:bool)
signal boardObjects_updated(lookup:Dictionary[int, StateBoardObject])
signal piecesLeft_updated(total:int)
signal goal_updated(goalnum:int)
signal campaign_changed(campaign:CampaignContext)
signal slotContextHash_updated(ctx:int)
signal started()

class StateItem:
	var id:int
	var loc_id:int
	var sender_id:int
	var senderName:String = "someone"
	var receiverName:String = "someone"
	var locationName:String = "somewhere"
	var gameName:String = "game"
	var classification:StringName = "filler"
	var isLocal:bool = true
	var streak:Streak = null
	var used:bool = false ## Set to true when used as an effect, to prevent using again
	var usedTrapLink:bool = false ## Set to true to avoid sending to trap link again
	var data:CONSTANTS.ItemData:
		get:
			return CONSTANTS.ITEMS.get(id)
	static func fromNetworkItem(netItem:NetworkItem) -> StateItem:
		var si := StateItem.new()
		si.id = netItem.id
		si.loc_id = netItem.loc_id
		si.sender_id = netItem.src_player_id
		si.isLocal = netItem.src_player_id == 0 or netItem.is_local()
		si.classification = (
			"proguseful" if netItem.is_prog() and (netItem.flags & AP.ItemClassification.USEFUL)
			else "progression" if netItem.is_prog()
			else "trap" if netItem.flags & AP.ItemClassification.TRAP
			else "useful" if netItem.flags & AP.ItemClassification.USEFUL
			else "filler"
		)
		if Archipelago.conn:
			si.senderName = Archipelago.conn.get_player_name(netItem.src_player_id)
			si.receiverName = Archipelago.conn.get_player_name(netItem.dest_player_id)
			si.locationName = Archipelago.conn.get_gamedata_for_player(netItem.src_player_id).get_loc_name(netItem.loc_id)
			si.gameName = Archipelago.conn.get_game_for_player(netItem.src_player_id)
		LocationContext.getOrCreateFromNetItem(netItem).attachStateItem(si)
		return si

	static func fromId(_id:int) -> StateItem:
		var si := StateItem.new()
		si.id = _id
		si.gameName = "Dracomino"
		si.locationName = "Debug Command"
		return si

	static func fromInternalName(internalName:StringName) -> StateItem:
		var si := StateItem.fromId(CONSTANTS.ITEM_NAME_TO_ID.get(internalName, 0))
		return si

	func getClassificationColor() -> Color:
		match classification:
			"proguseful": return CONSTANTS.COLOR.PROGUSEFUL
			"progression": return CONSTANTS.COLOR.PROGRESSION
			"trap": return CONSTANTS.COLOR.TRAP
			"useful": return CONSTANTS.COLOR.USEFUL
		return CONSTANTS.COLOR.FILLER

class StateBoardObject: ## Context data for state of board objects
	var loc_id:int = 0 ## Corresponding location id for this object, or 0 for non-location objects
	var objectName:StringName ## Corresponding scene name in res://objects/boardobjects
	var coordinates:Vector2i ## Coordinates object would spawn on the board, starting at Line 1, moving upward
	var index:int = -1 ## Index in the placement array. Used as an id for board if 0 or more
	var homeLine:int = -1 ## Line this belongs to, despite coordinates. Use to determine which act this belongs in 
	var isLocation:
		get:
			return loc_id > 0

	func _init(_coordinates:Vector2i, _objectName:StringName, _loc_id:int = 0, _index:int = -1) -> void:
		coordinates = _coordinates
		objectName = _objectName
		loc_id = _loc_id
		index = _index

	func getLocationContext() -> LocationContext:
		if isLocation:
			return LocationContext.getFromId(loc_id)
		return null

class Streak:
	var size:int = 0
	static var NOTABLE_THRESHOLD:int = 4

class LocationContext:
	signal item_updated(item:NetworkItem)
	
	static var cache:Dictionary[int, LocationContext] = {}
	static var lastLineLocation:int
	static var lastBoardObjectLocation:int

	var stateItem:StateItem
	var item:NetworkItem:
		set(value):
			if item == value: return
			item = value
			if item: item_updated.emit(item)
	var hinted:bool = false:
		set(value):
			if hinted == value: return
			hinted = value
			if hinted and item: item_updated.emit(item)

	static func getFromId(loc_id:int) -> LocationContext: ## Get context from location id
		if not cache.has(loc_id):
			cache[loc_id] = LocationContext.new()
		return cache[loc_id]

	static func getOrCreateFromNetItem(netItem:NetworkItem) -> LocationContext: ## Get or create context from network item
		# Make context if not existent
		if not cache.has(netItem.loc_id):
			cache[netItem.loc_id] = LocationContext.new()
		# Set net item if it's null
		if not cache[netItem.loc_id].item:
			cache[netItem.loc_id].item = netItem

		return cache[netItem.loc_id]
	
	static func clearCache() -> void: ## Clear cache for a new seed
		cache.clear()
		lastLineLocation = 0
		lastBoardObjectLocation = 0

	func attachStateItem(si:StateItem) -> LocationContext:
		stateItem = si
		return self

class PieceContext:
	var name:StringName
	var prettyName:String:
		get():
			return name as String if prettyName.is_empty() else prettyName
	var stateItem:StateItem
	var effects:Dictionary[StringName, StateItem] = {}
	var colorId:int = -1
	var orientationId:int = -1
	var instantSpawn:bool = false
	var aether:float = 0
	static var fallbackRandom:RandomNumberGenerator = RandomNumberGenerator.new()
	func _init(_stateItem:StateItem) -> void:
		stateItem = _stateItem
		if stateItem.data:
			name = stateItem.data.prettyName
			aether = DracominoUtil.getAetherValueOfItem(stateItem.data)
		randomizeColor()
		randomizeOrientation()
	func randomizeColor(random:RandomNumberGenerator = fallbackRandom) -> PieceContext:
		if FlagManager.isFlagSet("legacy_piece_colors"):
			colorId = CONSTANTS.LEGACY_PIECE_COLOR_MAPPINGS[random.randi_range(0, CONSTANTS.LEGACY_PIECE_COLOR_MAPPINGS.size() - 1)]
		else:
			colorId = random.randi_range(CONSTANTS.NUMBER_OF_PIECE_COLORS_MIN, CONSTANTS.NUMBER_OF_PIECE_COLORS_MAX - 1)
		return self
	func randomizeOrientation(random:RandomNumberGenerator = fallbackRandom) -> PieceContext:
		orientationId = random.randi_range(0,3)
		return self
	func setEffects(_effects:Dictionary[StringName, StateItem]) -> PieceContext:
		effects.merge(_effects, true)
		return self
	func setInstantSpawn(_instantSpawn:bool = true) -> PieceContext:
		instantSpawn = _instantSpawn
		return self

class CampaignContext:
	signal checkpoint_changed(act:ActContext)

	var acts:Array[ActContext] = []
	var location_id_to_act:Dictionary[int, ActContext] ## Missing locations lookup for acts; Gets erased when location checked
	var line_to_act:Dictionary[int, ActContext] ## Line lookup for acts; Does not get erased
	var checkpoint:ActContext:
		set(value):
			if checkpoint == value: return
			checkpoint = value
			checkpoint_changed.emit(value)
	var errors:Array[Dictionary] ## A list of errors that gets filled on creation

	static var CLASSIC_CAMPAIGN_LINES_PER_ACT:int = 20

	enum ERROR_TYPE {
		MISSING_CHAPTER,
		MISSING_ACT,
	}
	var _updateActs_deferred_called:bool = false

	func _init() -> void:
		SignalBus.getSignal("stateflag_changed", "total_aether_value").connect(updateActs_deferred)
		SignalBus.getSignal("stateflag_changed", "rotate").connect(updateActs_deferred)

	## Generate a classic campaign
	static func ClassicCampaign(lines:int, linesPerAct:int = CLASSIC_CAMPAIGN_LINES_PER_ACT) -> CampaignContext:
		var c:CampaignContext = CampaignContext.new()

		# Force minimum 1 line
		lines = max(1, lines)
		linesPerAct = max(1, linesPerAct)

		# Each act will have no less than lines per act, unless there's not enough lines for a full act
		var numActsToMake:int = max(1, floor(lines/linesPerAct))
		var remainingLines:int = lines
		for i:int in range(numActsToMake):
			var act:ActContext = ActContext.new(linesPerAct, true)
			act.prettyName = "Line %s"%((i*linesPerAct)+1)
			c.addAct(act)
			remainingLines -= linesPerAct

		if not c.acts.is_empty():
			# Add remaining lines to last act
			(c.acts.back() as ActContext).lines += remainingLines
			# Set a checkpoint
			c.checkpoint = c.acts.front() as ActContext
		
		c.buildLineActLookup()
		return c

	## Generate a story campaign
	static func StoryCampaign(actDataList:Array = []) -> CampaignContext:
		var c:CampaignContext = CampaignContext.new()
		for actData:Variant in actDataList:
			if actData is Dictionary:
				var chapterId:StringName = actData.get("chapter", "") as StringName
				var chapter:Story.Chapter = Story.CHAPTERS.get(chapterId)
				var act:ActContext = ActContext.new(actData.get("lines", 20) as int, bool(actData.get("continuation", false)))
				act.prettyName = actData.get("name", "Unknown Act")
				c.addAct(act)
				if chapter is Story.Chapter:
					var actId:StringName = actData.get("id", "") as StringName
					# If there's an error here, is a problem with the apworld
					if not chapter.acts.has(actId):
						printerr("Chapter %s does not have act %s"%[chapter.prettyName, actId])
					var actDefinition:Story.Act = chapter.acts.get(actId)
					if actDefinition is Story.Act:
						act.applyDefinition(actDefinition)
					else:
						# This act doesn't exist in this chapter
						c.errors.append({
							type = ERROR_TYPE.MISSING_ACT,
							chapterId = chapterId,
							actName = act.prettyName,
						})
				else:
					# This chapter doesn't exist in this version of the game
					c.errors.append({
						type = ERROR_TYPE.MISSING_CHAPTER,
						chapterId = chapterId,
					})

		if not c.acts.is_empty():
			# Set a checkpoint
			c.checkpoint = c.acts.front() as ActContext

		c.buildLineActLookup()
		return c

	# === Functions ===
	func addAct(act:ActContext) -> void: ## Add act to campaign and connect signals
		acts.append(act)
		act.load_requested.connect(loadAct.bind(act))
		act.selectable_changed.connect(_on_act_selectable_changed.bind(act))

	func getActAtLine(line:int) -> ActContext: ## Gets the act that contains the line, or returns last act if out of bounds
		if line_to_act.has(line):
			return line_to_act[line]
		return acts.back()

	func buildLineActLookup() -> void: ## Builds the lookup table to find act at line and set their offset too
		line_to_act.clear()
		var line:int = 0
		var startingLine:int = 0
		for act:ActContext in acts:
			act.offset = startingLine
			startingLine += act.lines
			for i:int in range(act.lines):
				line_to_act[line] = act
				line += 1

	func registerMissingLocationByLine(loc_id:int, line:int) -> void: ## Registers a missing location into its proper act
		if location_id_to_act.has(loc_id):
			# Don't register if already did
			return
		var act:ActContext = getActAtLine(line)
		assert(act != null, "Tried to register a missing location for nonexistent act")
		if act is ActContext:
			act.registerMissingLocation(loc_id)
			location_id_to_act[loc_id] = act

	func removeMissingLocation(loc_id:int) -> void: ## Remove a missing location from its act because it was checked; Do nothing if already checked
		var act:ActContext = location_id_to_act.get(loc_id, null)
		if act is ActContext:
			var existed:bool = location_id_to_act.erase(loc_id)
			act.removeMissingLocation(loc_id)
			if existed:
				updateActs_deferred()

	func cleanUp(): ## Clean up this object. It frees anyway when unreferenced anyway, but being extra cautious
		SignalBus.getSignal("stateflag_changed", "total_aether_value").disconnect(updateActs_deferred)
		SignalBus.getSignal("stateflag_changed", "rotate").disconnect(updateActs_deferred)
		for act:ActContext in acts:
			act.disconnectSignals()
		for dict:Dictionary in checkpoint_changed.get_connections():
			(dict["signal"] as Signal).disconnect(dict["callable"] as Callable)
		line_to_act.clear()

	func loadCheckpoint():
		loadAct(checkpoint)

	func loadAct(act:ActContext) -> void:
		checkpoint = act
		SignalBus.getSignal("restartGame").emit()

	func getCheckpointLine() -> int: ## Get the line the current checkpoint starts on
		return checkpoint.offset

	func getConsecutiveStartingLinesMappings(numLines:int) -> Array[int]: ## Get a range of line mappings, restricted if next act is not a continuation
		var line:int = getCheckpointLine()
		var consecutiveLines:Array[int] = [line] as Array[int]
		numLines -= 1
		line += 1
		while numLines > 0 and isLineContinuation(line):
			consecutiveLines.append(line)
			numLines -= 1
			line += 1
		return consecutiveLines
	
	func isLineContinuation(line:int) -> bool: ## Is this line a continuation of the line before
		var prev:ActContext = line_to_act.get(line - 1)
		var here:ActContext = line_to_act.get(line)
		if prev == here:
			# Prev line is in same act
			return true
		if here is ActContext:
			# This is the beginning of an act. Check if it's a continuation
			return here.isContinuation
		# This isn't an act, so make dummy lines
		return true

	func getCheckpointAetherCost() -> float: ## Get the aether cost of current checkpoint
		var aether:float = 0
		for act:ActContext in acts:
			if act == checkpoint:
				return aether
			aether += act.aetherCapacity 
		return 0

	func getLastSelectableCheckpoint() -> ActContext: ## Get last selectable checkpoint
		var lastCheckpoint:ActContext
		for act:ActContext in acts:
			if act.selectable:
				lastCheckpoint = act
			else:
				break
		return lastCheckpoint

	func updateCheckpoint() -> void: ## Set acts as selectable and get last checkpoint once game is first loaded
		updateActs()
		checkpoint = getLastSelectableCheckpoint()

	func updateActs_deferred() -> void:
		if not _updateActs_deferred_called:
			_updateActs_deferred_called = true
			updateActs.call_deferred()

	func updateActs() -> void: ## Figure out which acts are available with aether collected
		_updateActs_deferred_called = false
		var aether:float = FlagManager.getTotalCountAmount("total_aether_value")
		var previousCompleted:bool = true
		for act:ActContext in acts:
			act.selectable = previousCompleted and aether >= 0
			if previousCompleted and not act.isLogicallyCleared():
				previousCompleted = false
			aether -= act.aetherCapacity

	func reset() -> void: ## Tell acts to reset their triggers
		for act:ActContext in acts:
			act.isActive = false
			act.resetTriggers()

	func triggerObjectCollected(state:StateBoardObject) -> void: ## Tell object's belonging act to trigger object collect effect
		var act:ActContext = getActAtLine(state.coordinates.y if state.homeLine < 0 else state.homeLine)
		act.triggerObjectCollected(state)

	func triggerItemReceived(itemName:StringName, amount:int) -> void: ## Tell active acts to trigger item received events
		for act:ActContext in acts:
			if act.isActive:
				act.triggerItemReceived(itemName, amount)
	
	# === Events ===
	func _on_act_selectable_changed(isSelectable:bool, act:ActContext) -> void:
		if isSelectable:
			# Automatically set act as checkpoint if previous is immediately before
			var prevIndex:int = acts.find(act) - 1
			if prevIndex >= 0:
				if acts[prevIndex] == checkpoint:
					checkpoint = act
		elif act == checkpoint:
			# Since this is unselectable now, select a new valid checkpoint
			checkpoint = getLastSelectableCheckpoint()

	func _on_DracominoHandler_lineMappings_updated(lineMappings:Dictionary):
		if lineMappings.has(0):
			var bottomLine:int = int(lineMappings.get(0, 0))
			var act:ActContext = getActAtLine(bottomLine)
			act.triggerLineReach(bottomLine - act.offset)

		# Set acts as active
		for v:int in lineMappings.values():
			var act:ActContext = line_to_act.get(v)
			if act is ActContext:
				act.isActive = true

	func _on_DracominoHandler_gotLines_updated(gotLines:Dictionary):
		var numGotLinesByAct:Dictionary[ActContext, int]
		for k:int in gotLines.keys():
			if gotLines[k]:
				var act:ActContext = line_to_act.get(k)
				if act:
					numGotLinesByAct[act] = numGotLinesByAct.get(act, 0) + 1
		for act:ActContext in numGotLinesByAct.keys():
			act.triggerLinesCleared(numGotLinesByAct[act])

class ActContext:
	signal completed()
	signal selectable_changed(isSelectable:bool)
	signal load_requested()

	var prettyName:StringName = "Unnamed Act"
	var lines:int
	var offset:int ## The line this act starts in the campaign, set by the campaign
	var missingLocations:Dictionary[int, bool] ## Locations present in this act; bool is always true (erase when checked)
	var selectable:bool = false:
		set(value):
			if selectable == value: return
			selectable = value
			selectable_changed.emit(value)
	var aetherCapacity:float ## The amount of aether it takes to complete this act
	var isContinuation:bool ## Combine seamlessly with the act before
	var isActive:bool ## This act has lines mapped on the board since restarting; Set by campaign
	var triggers:Array[EventTriggerContext] = []

	func _init(_lines:int = 20, _isContinuation:bool = false) -> void:
		lines = _lines
		isContinuation = _isContinuation
		# TODO: Handle variable line size around here
		aetherCapacity = lines * Board.BOUNDS.size.x * CONSTANTS.AETHER_PER_BLOCK

	func registerMissingLocation(loc_id:int) -> void: ## Add a missing location
		missingLocations[loc_id] = true

	func removeMissingLocation(loc_id:int) -> void: ## Removed checked locations from this act; Emits completed when last location is checked
		if missingLocations.is_empty():
			return
		assert(missingLocations.has(loc_id), "Location id %s is not in act"%loc_id)
		missingLocations.erase(loc_id)

		if missingLocations.is_empty():
			completed.emit()

	func disconnectSignals() -> void: ## Disconnect signals for clean up (probably unnecessary)
		for s:Signal in [completed, selectable_changed, load_requested] as Array[Signal]:
			for dict:Dictionary in s.get_connections():
				(dict["signal"] as Signal).disconnect(dict["callable"] as Callable)

	func isCompleted() -> bool:  ## Are all locations in this act checked?
		return missingLocations.is_empty()

	func isLogicallyCleared() -> bool: ## Is this act completed and in logic?
		return isCompleted() and FlagManager.isFlagSet("rotate")

	func loadAct() -> void: ## Emits the signal to load this act
		load_requested.emit()

	func applyDefinition(actDefinition:Story.Act) -> void: ## Applies an act's definition from Story
		for trigger:Story.EventTrigger in actDefinition.triggers:
			var ctx:EventTriggerContext = EventTriggerContext.new(trigger)
			triggers.append(ctx)
			if trigger is Story.OnSignalEventTrigger:
				(trigger as Story.OnSignalEventTrigger).sig.connect(_on_signal_event_triggered.bind(ctx))

	func resetTriggers() -> void: ## Reset repeatable triggers
		for ctx:EventTriggerContext in triggers:
			if ctx.trigger.repeatable:
				ctx.isTriggered = false

	func triggerLineReach(line:int) -> void: ## Trigger events on line reached
		for ctx:EventTriggerContext in triggers:
			if not ctx.isTriggered:
				if ctx.trigger is Story.LineReachedEventTrigger:
					if (ctx.trigger as Story.LineReachedEventTrigger).line <= line:
						ctx.activate()

	func triggerLinesCleared(amount:int) -> void: ## Trigger events on lines cleared
		var ratio:float = float(amount)/lines
		for ctx:EventTriggerContext in triggers:
			if not ctx.isTriggered:
				if ctx.trigger is Story.LinesClearedEventTrigger:
					if (ctx.trigger as Story.LinesClearedEventTrigger).amount <= amount:
						ctx.activate()
				elif ctx.trigger is Story.LineRatioClearedEventTrigger:
					if (ctx.trigger as Story.LineRatioClearedEventTrigger).ratio <= ratio:
						ctx.activate()

	func triggerObjectCollected(state:StateBoardObject) -> void: ## Trigger events on object collected
		var flagName:StringName = "boardobjects_active_"+state.objectName
		# Since the flag will take a bit to update, wait for the signal
		await SignalBus.getSignal("stateflag_changed", flagName)
		var isLast:bool = not FlagManager.isFlagSet(flagName)		
		for ctx:EventTriggerContext in triggers:
			if not ctx.isTriggered:
				if ctx.trigger is Story.ObjectCollectedEventTrigger:
					if (ctx.trigger as Story.ObjectCollectedEventTrigger).objectName == state.objectName:
						ctx.activate()
				elif isLast and (ctx.trigger is Story.ObjectsAllCollectedEventTrigger):
					if (ctx.trigger as Story.ObjectsAllCollectedEventTrigger).objectName == state.objectName:
						ctx.activate()

	func triggerItemReceived(itemName:StringName, amount:int) -> void: ## Trigger events on item received
		for ctx:EventTriggerContext in triggers:
			if not ctx.isTriggered:
				if ctx.trigger is Story.ItemReceivedEventTrigger:
					var trigger:Story.ItemReceivedEventTrigger = ctx.trigger
					if trigger.itemName == itemName and trigger.amount <= amount:
						ctx.activate()

	func _on_signal_event_triggered(ctx:EventTriggerContext):
		if isActive and not ctx.isTriggered:
			ctx.activate()

class EventTriggerContext:
	var isTriggered:bool = false
	var trigger:Story.EventTrigger

	func _init(_trigger:Story.EventTrigger) -> void:
		trigger = _trigger

	func activate() -> void:
		if isTriggered:
			return
		if trigger.condition and not FlagManager.isFlagSet(trigger.condition):
			return
		var fx:EffectHandler.Effect = trigger.effect
		if fx.canTriggerFn.call():
			fx.triggerFn.call()
			isTriggered = true

#===== Virtuals =====
func _ready() -> void:
	Archipelago.connected.connect(_on_connected)
	Archipelago.remove_location.connect(_on_remove_location)

	# Create flag holder
	resetSeedFlagHolder()

	# Set up effect handler
	effectHandler = EffectHandler.new()
	add_child(effectHandler)

	# Add Dracomino specific commands
	DracominoCommandManager.addCommand("GETITEM", giveItemCommand).bind(self).setArgHint("name")
	DracominoCommandManager.addCommand("TRIGGEREFFECT", triggerEffectCommand).bind(self).setArgHint("name").setInvisible()

	# Set up trap link signal
	SignalBus.getSignal("stateflag_set", "trap_link").connect(Archipelago.set_traplink.bind(true))
	SignalBus.getSignal("stateflag_cleared", "trap_link").connect(Archipelago.set_traplink.bind(false))

	# Make the EnergyLink tag appear when energy link is enabled
	SignalBus.getSignal("stateflag_set", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", true))
	SignalBus.getSignal("stateflag_cleared", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", false))

#===== Functions =====
func reset():
	currentIndex = 0
	_effectBuffer.clear()
	seedFlagHolder.count("shapes_left", "subtracted", 0)
	gotLines.clear()
	lineMappings.clear()
	# Reset randoms
	color_random.state = color_randomSaveState
	rotate_random.state = rotate_randomSaveState
	var startingLine:int = 0
	var aetherCost:float = 0
	if campaign is CampaignContext:
		campaign.reset()
		startingLine = campaign.getCheckpointLine()
		seedFlagHolder.count("lines_cleared", "starting_line", startingLine)
		aetherCost = campaign.getCheckpointAetherCost()
		# Fill visible line mappings
		var consecutiveLines:Array[int] = campaign.getConsecutiveStartingLinesMappings(Board.BOUNDS.size.y)
		for i:int in range(consecutiveLines.size()):
			lineMappings[i] = consecutiveLines[i]
	else:
		# Fill visible line mappings
		for i in range(Board.BOUNDS.size.y):
			lineMappings[i] = i + startingLine
	# Set index forward until aether cost is spent
	skipAetherWorthOfPieces(aetherCost)

	lineMappings_updated.emit(lineMappings)
	gotLines_updated.emit(gotLines)

	effectHandler.on_board_reset()

func newSeedReset():
	print("Resetting everything because new seed!")
	victory = false
	collectedItems.clear()
	missingLocations.clear()
	missingLines.clear()
	checkedLocations.clear()
	collectedAbilities.clear()
	allLineLocations.clear()
	missingPickups.clear()
	LocationContext.clearCache()
	if campaign is CampaignContext:
		campaign.cleanUp()
		campaign = null
	
	seedFlagHolder.count("lines_cleared", "starting_line", 0)
	hintedRotateAbilities.clear()
	resetSeedFlagHolder()
	# Reset randoms
	color_random.seed = slotContextHash
	color_randomSaveState = color_random.state
	rotate_random.seed = slotContextHash+1
	rotate_randomSaveState = rotate_random.state

func resetSeedFlagHolder():
	if seedFlagHolder: seedFlagHolder.queue_free()
	if retroFlagHolder: retroFlagHolder.queue_free()
	seedFlagHolder = FlagHolder.new(FlagHolder.PRIORITY.WORLD)
	retroFlagHolder = FlagHolder.new(FlagHolder.PRIORITY.WORLD)
	FlagManager.HANDLERS.WORLD.setAsFlagHolder(seedFlagHolder)
	add_child(seedFlagHolder)
	add_child(retroFlagHolder)

func getNextPiece() -> PieceContext:
	var numItems := collectedItems.size()
	# Iterate through all items
	while currentIndex < numItems:
		var stateItem := collectedItems[currentIndex]
		var item:CONSTANTS.ItemData = CONSTANTS.ITEMS.get(stateItem.id)
		if item is CONSTANTS.ItemData:
			match item.type:
				"shape":
					# Apply any effects from the effect buffer first
					var effects:Dictionary[StringName, StateItem] = {}
					var isTrap:bool = item.tags.has(&"trap")
					for fx:StateItem in _effectBuffer.duplicate():
						var fx_item := CONSTANTS.ITEMS[fx.id]
						if isTrap and fx_item.type == "modifier":
							# Don't enchant traps
							continue
						match fx_item.type:
							"on_lock", "modifier", "on_spawn":
								if not effects.get(fx_item.type):
									effects[fx_item.type] = fx
									_effectBuffer.erase(fx)
					currentIndex += 1
					seedFlagHolder.count("shapes_left", "subtracted", -1, true)
					var pieceContext:PieceContext = PieceContext.new(stateItem).randomizeColor(color_random).randomizeOrientation(rotate_random).setEffects(effects)
					if isTrap and stateItem.used:
						# Don't repeat shape traps. Yes, we went through making its entire context so we can let the random do its thing
						continue
					return pieceContext
				"on_lock", "modifier", "on_spawn":
					_effectBuffer.append(stateItem)
		currentIndex += 1
	return null

func skipAetherWorthOfPieces(aetherAmount:float) -> void:
	while aetherAmount > 0:
		var piece:PieceContext = getNextPiece()
		if piece == null:
			return
		aetherAmount -= piece.aether

func sendLocation(loc_id:int):
	if not seedIsValid:
		return
	# Send the location
	if missingLocations.get(loc_id, false):
		if Archipelago.conn:
			Archipelago.collect_location(loc_id)
			print("Sending location: ", CONSTANTS.LOCATIONS[loc_id].prettyName)
		else:
			print("Will send ", CONSTANTS.LOCATIONS[loc_id].prettyName, " to server when reconnected.")
		
		if campaign:
			campaign.removeMissingLocation(loc_id)
	else:	
		print("Already sent: ", CONSTANTS.LOCATIONS[loc_id].prettyName)
	
	missingLocations.erase(loc_id)
	checkedLocations[loc_id] = true
	# TODO: Only board objects that are currency are currency
	if id_to_boardObject.has(loc_id):
		addLocationToCoinCurrency(loc_id)

func sendLine(lineIndex:int):
	if lineIndex >= allLineLocations.size():
		return

	print("Send location id for line ", lineIndex)
	missingLines[lineIndex] = false
	missingLines_updated.emit(missingLines)
	sendLocation(allLineLocations[lineIndex])
	LocationContext.lastLineLocation = allLineLocations[lineIndex]

func sendVictory():
	victory = true
	Archipelago.set_client_status(Archipelago.ClientStatus.CLIENT_GOAL)
	Overlay.queueAnnouncement("You reached your goal! Congratulations!")

func giveMana(amount:float, shareThroughEnergyLink:bool = true) -> void:
	# Send mana/energy
	var manaEarned:float = amount
	var sharedMana:float = 0.0
	if shareThroughEnergyLink and FlagManager.isFlagSet("energy_link"):
		sharedMana = manaEarned * CONSTANTS.ENERGY_LINK_SHARE
		sendEnergy(round(sharedMana * CONSTANTS.MANA_TO_ENERGY_RATIO))
	seedFlagHolder.count("mana", "earned", manaEarned - sharedMana, true)

func sendEnergy(amount:int = 0):
	amount += _energySendBuffer
	_energySendBuffer = 0
	if amount == 0:
		return
	if Archipelago.conn:
		var args:Dictionary = {
			"key": "EnergyLink" + str(Archipelago.conn.team_id),
			"default": 0,
			"operations": [
				{"operation": "add", "value": amount},
			],
		}
		Archipelago.send_command("Set", args)
	else:
		_energySendBuffer = amount

func upgradeFeatures(generatedVersion:String = "0.0.0"): ## Add new features to old games
	# Make vertical shove always active
	seedFlagHolder.setFlag("vertical_shove")
	#
	var upgradeResult:Dictionary = {
		retrofitted = [],
	}
	if UserData.versionIsOlderThan(generatedVersion, "0.2.2"):
		var RETROFITTED_ABILITIES:Array[StringName] = [
			"kick",
			"lock_delay",
		]
		for internalName:StringName in RETROFITTED_ABILITIES:
			var id:Variant = CONSTANTS.ITEM_NAME_TO_ID.get(internalName)
			var item := CONSTANTS.ITEMS[id] if id != null else null
			if item:
				collectedAbilities[item.id] = 1
				if not seedFlagHolder.isFlagSet(item.internalName):
					var stateItem:StateItem = StateItem.fromInternalName(item.internalName)
					giveItem(stateItem)
					upgradeResult.retrofitted.append(item.prettyName)
		
		# Set legacy settings
		seedFlagHolder.setFlag("legacy_piece_colors")
		seedFlagHolder.setFlag("legacy_orientations")

	if upgradeResult.retrofitted.size():
		# TODO: This is an important message and probably should be forced to last longer
		notification_signal.emit("Retrofitted {items} into your game!".format({items=" and ".join(upgradeResult.retrofitted)}), CONSTANTS.COLOR.SPECIAL, false)

func resolveItem(option:String) -> StateItem:
	var item:StateItem
	if CONSTANTS.ITEM_NAME_TO_ID.has(option):
		return StateItem.fromInternalName(option)

	option = option.to_lower()
	for id in CONSTANTS.ITEMS:
		if CONSTANTS.ITEMS[id].prettyName.to_lower() == option:
			return StateItem.fromId(id)

	printerr("DracominoHandler.resolveItem: could not resolve item \"%s\""%option)
	return null

func giveItemCommand(option:String): ## Give you an item using the debug console
	var item:StateItem = resolveItem(option)
	if item and item.data:
		notification_signal.emit("Giving item from debug console: %s"%item.data.prettyName, CONSTANTS.COLOR.SPECIAL, true)
		giveItem(item)
	else:
		notification_signal.emit("Failed to give item: %s"%option, CONSTANTS.COLOR.ERROR, true)

func triggerEffectCommand(option:String): ## Triggers an effect immediately
	option = option.to_snake_case()
	if not effectHandler.EFFECTS.has(option):
		var msg:String = "%s is not an effect"%option
		printerr("DracominoHandler.triggerEffectCommand: ", msg)
		if Config.debugMode:
			notification_signal.emit("Trigger effect failed: "+msg, CONSTANTS.COLOR.ERROR, true)
		return
	var success:bool = effectHandler.triggerEffectByName(option)
	if Config.debugMode:
		if success:
			notification_signal.emit("Triggering effect: %s"%CONSTANTS.TRAP_ALIASES.get(option, option), CONSTANTS.COLOR.SPECIAL, true)
		else:
			notification_signal.emit("Trigger effect failed: %s does not meet conditions"%CONSTANTS.TRAP_ALIASES.get(option, option), CONSTANTS.COLOR.ERROR, true)

func triggerTrapLinkTrap(trapname:String, source:String = "") -> String: ## Triggers trap link trap immediately or buffers it
	var mapping:Variant = CONSTANTS.TRAP_LINK_MAPPINGS.get(trapname)
	var trapsToTrigger:Array[StringName] = []
	var triggeredTraps:Array[StringName] = []
	if mapping:
		if mapping is Array:
			trapsToTrigger.append_array(mapping)
		elif mapping is StringName or mapping is String:
			trapsToTrigger.append(mapping)

	if not trapsToTrigger.size():
		trapsToTrigger.append("random_trap")
		print("There is no alias for %s so we'll randomly pick %s"%[trapname, trapsToTrigger[0]])

	for alias in trapsToTrigger:
		var success = effectHandler.triggerEffectByName(alias)
		if success: triggeredTraps.append(CONSTANTS.TRAP_ALIASES.get(alias, alias))
	
	if triggeredTraps.size():
		return " and ".join(triggeredTraps)
	print("No traps were triggered: ", trapsToTrigger)
	return ""


func giveItem(item:StateItem):
	if not item: return
	collectedItems.append(item)
	if item.data:
		# Make tutorial selectable when just connecting
		if isJustConnected and item.data.tags.get("tutorial"):
			seedFlagHolder.setFlag(item.data.internalName)
		match item.data.type:
			# Detect shape streaks
			"shape":
				seedFlagHolder.count("shapes_left", "collected", 1, true)
				seedFlagHolder.count("shapes", item.data.internalName, 1, true)
				var aether:int = int(DracominoUtil.getAetherValueOfItem(item.data))
				if aether > 0:
					seedFlagHolder.count("total_aether_value", "collected", aether, true)
				var streak:Streak
				# Get last shape in collectedItems and get its streak object if the same as this one 
				var index:int = collectedItems.size() - 2 # Get the one right before the one we just added
				while index >= 0 and collectedItems[index]:
					if collectedItems[index].id in CONSTANTS.ITEMS and CONSTANTS.ITEMS[collectedItems[index].id].tags.get("shape"):
						if collectedItems[index].id == item.id:
							streak = collectedItems[index].streak
						break
					index -= 1
				if not streak: streak = Streak.new()
				streak.size += 1
				item.streak = streak
			# Register collected ability or misc item
			"ability", "misc":
				if collectedAbilities.has(item.id):
					collectedAbilities[item.id] += 1
				else:
					collectedAbilities[item.id] = 1

				# Add flag for ability
				match item.data.type:
					"ability": seedFlagHolder.count(item.data.internalName, "collected", collectedAbilities[item.id])
				# Add has_ flag for both abilities and misc
				seedFlagHolder.count("has_"+item.data.internalName, "collected", collectedAbilities[item.id])

				# We were given an item that doesn't exist, so put it in our other flag holder so it appears in the ability bar
				if not seedFlagHolder.isFlagSet("existing_"+item.data.internalName):
					retroFlagHolder.setFlag("existing_"+item.data.internalName, collectedAbilities[item.id])

				# Keep track of rotate abilities collected
				if item.data.tags.get("rotate"):
					seedFlagHolder.count("rotate", item.data.internalName, 1)

				# Announce the ability you got
				if not isJustConnected:
					Overlay.queueAnnouncement("You got {item}!".format({item=item.data.prettyName}))

				# Trigger item received events in campaign
				if campaign:
					campaign.triggerItemReceived(item.data.internalName, collectedAbilities[item.id])
			# Trigger effects
			"on_lock", "on_spawn":
				if not isJustConnected:
					var result = triggerEffect(item)
					if not result:
						# Is this a delayed effect?
						var fx = effectHandler.getEffectObject(item)
						if fx.context.has("delayed"):
							# Then spawn it again delayed
							var tween:Tween = create_tween()
							tween.tween_callback(triggerEffect.bind(item, ["delayed"] as Array[StringName]))\
							.set_delay(DELAYED_EFFECT_CONTEXT_DURATION/Config.getSetting("gravity", 1.0))

	else:
		printerr("Obtained invalid item: id: {id}; name: {name}; You may be running an outdated version of the client!"
			.format({id=item.id,name=Archipelago.conn.get_gamedata_for_player().get_item_name(item.id) if Archipelago.conn else "unknown"})
		)

func triggerEffect(stateItem:StateItem, context:Array[StringName] = []) -> bool: ## Return true on null or success (false means try again but delayed)
	if not stateItem or not stateItem.data:
		return true
	var result:bool = false
	if FlagManager.isFlagSet("versus_mode"):
		result = true
	else:
		result = effectHandler.tryToTriggerEffect(stateItem, false, context)
	if result and FlagManager.isFlagSet("trap_link"):
		var trapLinkAlias:String = CONSTANTS.TRAP_ALIASES.get(stateItem.data.internalName, "")
		if trapLinkAlias and Archipelago.conn and not stateItem.usedTrapLink:
			stateItem.usedTrapLink = true
			Archipelago.conn.send_traplink(trapLinkAlias)
			print("Sending trap: ", trapLinkAlias)
	return result

func addLocationToCoinCurrency(loc_id): ## Add coins to currency (be careful not to use line locations here)
	seedFlagHolder.count("coins", "coin_%s"%loc_id, 1)

#===== Events =====
func _on_connected(conn:ConnectionInfo, json:Dictionary):
	isJustConnected = true
	get_tree().create_timer(2, true).timeout.connect(set.bind("isJustConnected", false))
	
	# Connect signals
	conn.deathlink.connect(_on_deathlink)
	conn.traplink.connect(_on_traplink)
	conn.obtained_item.connect(_on_obtained_item)
	conn.set_hint_notify(_on_on_hint_update)

	# Check min game version
	var minGameVersion:String = conn.slot_data.get("min_game_version", "0.1.0")
	var warningDialog:AcceptDialog
	if UserData.versionIsOlderThan(Config.versionNum, minGameVersion):
		warningDialog = VERSION_WARNING_DIALOG_SCENE.instantiate()
		warningDialog.dialog_text = "Game version {version} is too old for this slot data and may not work correctly! Target version is {minGameVersion} or newer!".format({
			version=Config.versionNum,
			minGameVersion=minGameVersion,
		})
		add_child(warningDialog)
		warningDialog.popup_centered()
		warningDialog.visibility_changed.connect(warningDialog.queue_free)

	# Create seed hash
	var _conn_ctx = hash("{seed}_{player_id}_{team_id}".format({
		seed=conn.seed_name,
		player_id=conn.player_id,
		team_id=conn.team_id
	}))

	# Check if this is a brand new seed, player, and team, and do a full reset
	if slotContextHash != _conn_ctx:
		slotContextHash = _conn_ctx
		newSeedReset()
		
		# Set up a signal to reset the game once everything is loaded
		if is_instance_valid(warningDialog):
			warningDialog.tree_exited.connect(_on_newSeed_refresh_items)
		else:
			conn.refresh_items.connect(_on_newSeed_refresh_items.unbind(1), CONNECT_ONE_SHOT)

		conn.force_scout_all()

	goal = conn.slot_data.get("goal", -1)

	# Set death link
	Archipelago.set_deathlink(conn.slot_data.get("death_link", false) as bool)
	if "death_on_restart" in conn.slot_data:
		SignalBus.getSignal(
			"deathOnRestart_enabled" if conn.slot_data.get("death_on_restart", false)
			else "deathOnRestart_disabled"
		).emit()
	# Set energy link
	if conn.slot_data.get("energy_link", true):
		FlagManager.setFlag("energy_link")
	else:
		FlagManager.clearFlag("energy_link")
	# Set trap link
	if conn.slot_data.get("trap_link"):
		FlagManager.setFlag("trap_link")
	elif conn.slot_data.get("trap_link") == false:
		FlagManager.clearFlag("trap_link")
	else:
		Archipelago.set_traplink(FlagManager.isFlagSet("trap_link"))
	# Existing items
	var itemCounts:Variant = conn.slot_data.get("item_counts")
	if itemCounts is Dictionary:
		for id in itemCounts.keys():
			var item:CONSTANTS.ItemData = CONSTANTS.ITEMS.get(int(id))
			if item:
				seedFlagHolder.setFlag("existing_"+item.internalName, int(itemCounts[id]))
	else:
		# Older gens are unaware of item counts, so assume the abilities
		for abilityname in ["rotate_clockwise", "rotate_counterclockwise", "gravity", "soft_drop", "hard_drop"]:
			seedFlagHolder.setFlag("existing_"+abilityname)
	var requirements:Array = conn.slot_data.get("requirements", []) as Array
	var chapterNames:Dictionary = conn.slot_data.get("chapter_names", {}) as Dictionary
	# Set up campaign
	if campaign == null:
		var actDataList:Variant = conn.slot_data.get("acts")
		if actDataList is Array:
			campaign = CampaignContext.StoryCampaign(actDataList as Array)

		# Make a classic campaign if there isn't one
		if campaign == null:	
			campaign = CampaignContext.ClassicCampaign(goal)

		lineMappings_updated.connect(campaign._on_DracominoHandler_lineMappings_updated)
		gotLines_updated.connect(campaign._on_DracominoHandler_gotLines_updated)

	# Check if there were errors before aborting this load
	if campaign.errors.size():
		seedIsValid = false
		var errorDialog:AcceptDialog = VERSION_WARNING_DIALOG_SCENE.instantiate()
		errorDialog.dialog_text = "There were errors loading the story campaign:"
		var missingChapters:Array[StringName] = []
		var missingActs:Array[StringName] = []
		for error:Dictionary in campaign.errors:
			match error.get("type", ""):
				CampaignContext.ERROR_TYPE.MISSING_CHAPTER:
					var chapterName:String = chapterNames.get(error.get("chapterId"), error.get("chapterId", "Unknown Chapter"))
					if not missingChapters.has(chapterName):
						missingChapters.append(chapterName)
				CampaignContext.ERROR_TYPE.MISSING_ACT:
					var chapterName:String = chapterNames.get(error.get("chapterId"), error.get("chapterId", "Unknown Chapter"))
					var actName:String = chapterName + " - " + error.get("actName", "Unknown Act")
					if not missingActs.has(actName):
						missingActs.append(actName)
		if missingChapters.size():
			errorDialog.dialog_text += "\n Chapters are missing in this version: {chapters}".format({
				chapters = ", ".join(missingChapters)
			})
		if missingActs.size():
			errorDialog.dialog_text += "\n Acts are missing in this version: {chapters}".format({
				chapters = ", ".join(missingActs)
			})
		errorDialog.dialog_text += ""
		add_child(errorDialog)
		if warningDialog:
			warningDialog.tree_exiting.connect(errorDialog.popup_centered, CONNECT_ONE_SHOT)
		else:
			errorDialog.popup_centered()
		errorDialog.visibility_changed.connect(errorDialog.queue_free)

		return
	else:
		seedIsValid = true

	# Set randomize orientations
	var randomizeOrientations = conn.slot_data.get("randomize_orientations", false)
	if randomizeOrientations:
		seedFlagHolder.setFlag("randomize_orientations")
	else:
		seedFlagHolder.clearFlag("randomize_orientations")

	# Reset collected items
	seedFlagHolder.count("shapes_left", "collected", 0)
	seedFlagHolder.count("total_aether_value", "collected", 0)
	collectedItems.clear()
	collectedAbilities.clear()
	allLineLocations.clear()
	boardObjects.clear()
	missingLines.clear()
	missingPickups.clear()
	id_to_line.clear()
	id_to_boardObject.clear()

	var locsToCollect:Array[int] = []
	var _missingLocations_changed:bool = false
	var _allPickupLocations:Dictionary[StringName, Array]
	for loc_id:int in conn.slot_locations:
		var loc_data:CONSTANTS.LocationData = CONSTANTS.LOCATIONS.get(loc_id)
		if loc_data is CONSTANTS.LocationData:
			var checked:bool = conn.slot_locations[loc_id]
			# Sync missingLocations and checkedLocations with server
			if not checked:
				if checkedLocations.get(loc_id, false):
					# We got this while offline and need to sync to server
					locsToCollect.append(loc_id)
					checked = true
				else:
					if not missingLocations.get(loc_id, false):
						# This is a fresh load or different seed
						missingLocations[loc_id] = true
						_missingLocations_changed = true
			else:
				checkedLocations[loc_id] = true
				if missingLocations.get(loc_id, false):
					missingLocations.erase(loc_id)
					_missingLocations_changed = true
			if loc_data.isLineClear:
				allLineLocations.append(loc_id)
			elif loc_data.isBoardObject:
				if loc_data.objectName:
					if not _allPickupLocations.has(loc_data.objectName):
						_allPickupLocations[loc_data.objectName] = []
					_allPickupLocations[loc_data.objectName].append(loc_id)
				if not checked:
					missingPickups.append(loc_id)
				else:
					addLocationToCoinCurrency(loc_id)
			# Scout this
			conn.scout(loc_id, 0, _on_location_scouted)
		else:
			printerr("Got invalid location: id: {id}; name: {name}; You may be running an outdated version of the client!"
				.format({id=loc_id, name=conn.locations[loc_id].name})
			)
	#
	allLineLocations.sort()
	for k:StringName in _allPickupLocations:
		_allPickupLocations[k].sort()
		_allPickupLocations[k].reverse() # Prepare to pop the first objects first
	missingPickups.sort()

	# Create item pickup data
	var item_pickup_placements:Variant = conn.slot_data.get("item_pickup_placements", [])
	# Added version 1.0.0 probably
	var item_pickup_ids:Variant = conn.slot_data.get("item_pickup_ids")
	var item_pickup_id_mappings:Variant = conn.slot_data.get("item_pickup_id_mappings")
	# Create board objects states
	if item_pickup_placements is Array:
		for i:int in range(item_pickup_placements.size()):
			var placement:int = item_pickup_placements[i]
			# Map pickup id to object name
			var objectName:StringName = &"error" # Make default an error. TODO: Can put APWorld-specific error object here
			if item_pickup_ids is Array:
				if item_pickup_ids.size() > i:
					var item_pickup_id:int = 0
					item_pickup_id = int(item_pickup_ids[i])
					if item_pickup_id_mappings is Dictionary:
						# Get the mapped object name, or make error object if something weird is happening
						if item_pickup_id_mappings.has(item_pickup_id):
							objectName = item_pickup_id_mappings[item_pickup_id] as StringName
						else:
							# Unknown mapping (something is wrong with the APWorld)
							printerr("Error: Malformed slot data. Found missing item pickup id: ", item_pickup_id)
				else:
					# Out of bounds (something is wrong with the APWorld)
					printerr("Error: Malformed slot data. Index %s exceeds item_pickup_ids size"%i)
			else:
				# There is no item pickup mappings, so default to coin
				objectName = &"coin"
			#
			var vec:Vector2i = Vector2i(placement % Board.BOUNDS.size.x, floor(placement/Board.BOUNDS.size.x))
			var loc_id:Variant = _allPickupLocations.get(objectName, []).pop_back()
			if loc_id != null:
				# This is a location
				if missingLocations.get(loc_id, false):
					boardObjects[i] = StateBoardObject.new(vec, objectName, loc_id as int, i)
			else:
				# This isn't a location; it's just a regular board object or an error
				boardObjects[i] = StateBoardObject.new(vec, objectName, -1, i)
			
	
	# Set up lookup tables
	for i:int in range(allLineLocations.size()):
		id_to_line[allLineLocations[i]] = i
		missingLines[i] = missingLocations.get(allLineLocations[i], false)
		if missingLines[i]:
			campaign.registerMissingLocationByLine(allLineLocations[i], i)

	for sbo:StateBoardObject in boardObjects.values():
		if sbo.isLocation:
			id_to_boardObject[sbo.loc_id] = sbo
			if missingLocations.get(sbo.loc_id, false):
				campaign.registerMissingLocationByLine(sbo.loc_id, sbo.coordinates.y)

	# Sync with campaign (because reconnect)
	for loc_id:int in locsToCollect:
		campaign.removeMissingLocation(loc_id)

	if victory:
		sendVictory()

	# Send new state to board
	if _missingLocations_changed:
		missingLines_updated.emit(missingLines)
		boardObjects_updated.emit(boardObjects)

	# Sync with server
	if locsToCollect.size():
		Archipelago.collect_locations(locsToCollect)

	# Add new features to older games
	upgradeFeatures(conn.slot_data.get("generator_version", "0.0.0"))

	# Send started signal to start game
	if is_instance_valid(warningDialog):
		warningDialog.tree_exited.connect(started.emit)
	else:
		started.emit()

	# Send energy that couldn't be sent earlier
	sendEnergy.call_deferred()

func _on_newSeed_refresh_items():
	# Reset when everything is loaded
	if campaign is CampaignContext:
		campaign.updateCheckpoint()
		# Make acts announce when unlocked
		for act:ActContext in campaign.acts:
			act.selectable_changed.connect(
				func(isSelectable):
					if isSelectable:
						Overlay.queueAnnouncement("%s Checkpoint is unlocked!"%act.prettyName)
			)
	SignalBus.getSignal("restartGame").emit()

func _on_deathlink(source: String, cause: String, json: Dictionary):
	var vsmode:bool = FlagManager.isFlagSet("versus_mode")
	if not cause: cause = "Died."
	notification_signal.emit("{source}: {cause}".format({source=source, cause=cause}),
		CONSTANTS.COLOR.SPECIAL if vsmode else CONSTANTS.COLOR.DEATH,
		true
	)
	if vsmode:
		giveMana(CONSTANTS.MANA_PER_VERSUS_DEFEAT, false)

func _on_traplink(source: String, trapname: String, json: Dictionary):
	if not trapname: return
	var result:String = triggerTrapLinkTrap(trapname, source)
	if result:
		notification_signal.emit("{source} triggered {trapname}{result}!".format({
			source=source,
			trapname=trapname,
			result= "" if result == trapname else " as %s"%result,
		}), CONSTANTS.COLOR.TRAP, true)

func _on_obtained_item(item: NetworkItem):
	if not seedIsValid:
		return
	if not isJustConnected:
		var color = (
			CONSTANTS.COLOR.PROGUSEFUL if item.is_prog() and (item.flags & AP.ItemClassification.USEFUL)
			else CONSTANTS.COLOR.PROGRESSION if item.is_prog()
			else CONSTANTS.COLOR.TRAP if item.flags & AP.ItemClassification.TRAP
			else CONSTANTS.COLOR.USEFUL if item.flags & AP.ItemClassification.USEFUL
			else CONSTANTS.COLOR.FILLER
		)
		if item.is_local():
			notification_signal.emit("You found your {item}!".format({item=item.get_name()}), color, false)
		else:
			notification_signal.emit("{source} sent you your {item}!"
				.format({source=Archipelago.conn.get_player_name(item.src_player_id), item=item.get_name()}), color, false
			)
	var si:StateItem = StateItem.fromNetworkItem(item)
	giveItem(si)

func _on_on_hint_update(hints: Array[NetworkHint]):
	if Archipelago.conn:
		for hint:NetworkHint in hints:
			if hint.item.src_player_id == Archipelago.conn.player_id:
				LocationContext.getOrCreateFromNetItem(hint.item).hinted = true
			if hint.status == NetworkHint.Status.FOUND: continue
			if hint.item.dest_player_id == Archipelago.conn.player_id:
				# Only check hints for our abilities
				var item = CONSTANTS.ITEMS.get(hint.item.id)
				if item and item.tags.get("rotate"):
					hintedRotateAbilities[item.id] = StateItem.fromNetworkItem(hint.item)

func _on_remove_location(loc_id:int):
	var changed:bool = missingLocations.get(loc_id, false)
	missingLocations.erase(loc_id)
	if changed:
		if campaign:
			campaign.removeMissingLocation(loc_id)
		checkedLocations[loc_id] = true
		if id_to_line.has(loc_id):
			missingLines[id_to_line[loc_id]] = false
			missingLines_updated.emit(missingLines)
		elif id_to_boardObject.has(loc_id):
			boardObjects.erase(id_to_boardObject[loc_id].index)
			boardObjects_updated.emit(boardObjects)
			addLocationToCoinCurrency(loc_id)

func _on_Board_pieces_requested(callback:Callable, num:int) -> void:
	for i:int in range(num):
		var nextPiece:PieceContext = getNextPiece()
		if nextPiece:
			callback.call(nextPiece)
		else:
			print("Outta pieces!")
			break

func _on_Board_game_started() -> void:
	reset()

func _on_Board_lines_cleared(lines:Array) -> void:
	assert(lines.size() < Board.BOUNDS.size.y)
	var linesChanged:bool = false
	# Set lines as got
	for n:int in lines:
		if not lineMappings.has(n):
			continue
		linesChanged = true
		gotLines[lineMappings[n]] = true
		sendLine(lineMappings[n])
		# Shift line mappings
		var lastLine:int = n
		var lastMapping:int = lineMappings[n]
		for i:int in range(n, Board.BOUNDS.size.y-1):
			if lineMappings.has(i + 1):
				lineMappings[i] = lineMappings[i + 1]
				lastLine = i + 1
				lastMapping = lineMappings[i + 1]
			else:
				lineMappings.erase(i)
				break

		if campaign:
			if campaign.isLineContinuation(lastMapping + 1) and not gotLines.get(lastMapping + 1, false):
				# Reveal next line since it continues
				lineMappings[lastLine] = lastMapping + 1
			else:
				# The lines end here, so delete mappings
				lineMappings.erase(lastLine)
		else:
			# Reveal next line since there's no campaign data
			lineMappings[lastLine] = lastMapping + 1

	if linesChanged:
		lineMappings_updated.emit(lineMappings)
		gotLines_updated.emit(gotLines)
	
	giveMana(lines.size() * Board.BOUNDS.size.x * CONSTANTS.MANA_PER_BLOCK)

func _on_Board_item_pickedup(state:StateBoardObject) -> void:
	if state and state.isLocation:
		print("Picked up ", CONSTANTS.LOCATIONS[state.loc_id].prettyName)
		sendLocation(state.loc_id)
		LocationContext.lastBoardObjectLocation = state.loc_id
	if campaign:
		campaign.triggerObjectCollected(state)
	giveMana(CONSTANTS.MANA_PER_COIN)

func _on_Board_lines_cleared_updated(num:int) -> void:
	if not seedIsValid:
		return
	# Make NO_ROTATE death context only happen when you're putting the effort
	_canUseDeathContext_NO_ROTATE = num >= LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT
	# Send victory if reached goal
	if not victory and goal > 0 and FlagManager.getTotalCountAmount("lines_cleared") >= goal:
		sendVictory()
	# Send mana/energy
	sendEnergy()

func _on_Board_deathlink_earned(deathContext:DracominoUtil.DeathContext) -> void:
	if Archipelago.conn:
		var formatValues = {
			player = Archipelago.conn.get_player_name(),
			boardheight = str(Board.BOUNDS.size.y),
			totalpieces = str(FlagManager.getTotalCountAmount("shapes")),
		}
		formatValues.merge(DracominoUtil.getPronouns(), true)
		formatValues.merge(deathContext.formatValues, true)
		var contextTags = deathContext.contextTags.duplicate()
		var itemctx:PieceContext = deathContext.itemContext
		if itemctx is PieceContext and itemctx.stateItem is StateItem:
			var stateItem:StateItem = itemctx.stateItem
			# Add context of last piece if any
			contextTags.append("LOCAL_ITEM" if stateItem.isLocal else "NONLOCAL_ITEM")
			var item := CONSTANTS.ITEMS[stateItem.id]
			formatValues.merge({
				item = itemctx.prettyName,
				sender = stateItem.senderName,
				location = stateItem.locationName,
				game = stateItem.gameName,
			})
			# Add context for having no rotate
			if _canUseDeathContext_NO_ROTATE and not FlagManager.isFlagSet("rotate"):
				contextTags.append("NO_ROTATE")
				if hintedRotateAbilities.size():
					var _hintedRotateAbilities_array:Array[StateItem] = hintedRotateAbilities.values()
					var hintedRotate := _hintedRotateAbilities_array[randi_range(0,_hintedRotateAbilities_array.size()-1)]
					# Add context for hinted non-local rotates
					if not hintedRotate.isLocal:
						contextTags.append("NONLOCAL_ROTATE")
						formatValues.merge({
							sender_rotate = hintedRotate.senderName,
							location_rotate = hintedRotate.locationName,
							game_rotate = hintedRotate.gameName,
						})
			# Add context for streaks
			if stateItem.streak and stateItem.streak.size >= Streak.NOTABLE_THRESHOLD:
				contextTags.append("ITEM_STREAK")
				formatValues.merge({
					streaksize = stateItem.streak.size,
				})

		# Pick a template and generate a deathlink message
		var msg = DracominoUtil.generateDeathlinkMessage(deathContext.category, contextTags, formatValues) 
		Archipelago.conn.send_deathlink.call_deferred(msg)
		notification_signal.emit(msg, CONSTANTS.COLOR.DEATH, true)
		print(msg, deathContext.category, ": ", contextTags)

func _on_location_scouted(item:NetworkItem) -> void:
	LocationContext.getOrCreateFromNetItem(item)
