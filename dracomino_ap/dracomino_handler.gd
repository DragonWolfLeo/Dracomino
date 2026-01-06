class_name DracominoHandler extends Node

static var activeAbilities:Dictionary[String, int] = {} ## Static variable. Could probably be put somewhere neater
static var randomizeOrientations:bool = false ## Static variable. Could probably be put somewhere neater

var collectedItems:Array[StateItem] = []
var missingLocations:Dictionary[int, bool] = {}
var checkedLocations:Dictionary[int, bool] = {}
var victory:bool = false
var currentIndex:int = 0
var collectedAbilities:Dictionary[int, int] = {}
var gotLines:Dictionary[int, bool] = {}
var allLineLocations:Array[int] = []
var missingPickups:Array[int] = []
var missingPickupCoordinates:Dictionary[Vector2i, int] = {}
var lineMappings:Dictionary[int, int] = {}
var missingLines:Dictionary[int, bool] = {}
var id_to_line:Dictionary[int, int] = {}
var id_to_pickupCoord:Dictionary[int, Vector2i] = {}
var hintedRotateAbilities:Dictionary[int, StateItem] = {}
var goal:int = -1:
	set(value):
		if goal == value: return
		goal = value
		goal_updated.emit(goal)
var slotContextHash:int:
	set(value):
		if slotContextHash == value:
			return
		slotContextHash = value
		slotContextHash_updated.emit(slotContextHash)

var isJustConnected:bool = false
var _holdSlotLegacyEnabled:bool = false
var VERSION_WARNING_DIALOG_SCENE:PackedScene = load("res://ui/versionwarning_dialog.tscn")

var LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT:int = 8 ## For death context
var _canUseDeathContext_NO_ROTATE:bool = false ## For death context

signal lineMappings_updated(mappings:Dictionary[int, int])
signal missingLocations_updated(locs:Dictionary[int, bool])
signal missingLines_updated(locs:Dictionary[int, bool])
signal notification_signal(notif:String, color:Color, force:bool)
signal missingPickupCoordinates_updated(map:Dictionary[Vector2i, int])
signal activeAbilities_updated(abilities:Dictionary[String, int])
signal piecesLeft_updated(total:int)
signal goal_updated(goalnum:int)
signal slotContextHash_updated(ctx:int)

class StateItem:
	var id:int
	var loc_id:int
	var sender_id:int
	var senderName:String = "someone"
	var locationName:String = "somewhere"
	var gameName:String = "game"
	var isLocal:bool = true
	var streak:Streak = null
	static func fromNetworkItem(netItem:NetworkItem) -> StateItem:
		var si := StateItem.new()
		si.id = netItem.id
		si.loc_id = netItem.loc_id
		si.sender_id = netItem.src_player_id
		if Archipelago.conn:
			si.isLocal = netItem.src_player_id == 0 or netItem.is_local()
			si.senderName = Archipelago.conn.get_player_name(netItem.src_player_id)
			si.locationName = Archipelago.conn.get_gamedata_for_player(netItem.src_player_id).get_loc_name(netItem.loc_id)
			si.gameName = Archipelago.conn.get_game_for_player(netItem.src_player_id)
		return si

class Streak:
	var size:int = 0
	static var NOTABLE_THRESHOLD:int = 4

#===== Virtuals =====
func _ready() -> void:
	Archipelago.connected.connect(_on_connected)
	Archipelago.remove_location.connect(_on_remove_location)

#===== Functions =====
func reset():
	currentIndex = 0
	gotLines.clear()
	lineMappings.clear()
	# Fill visible line mappings
	for i in range(Board.BOUNDS.size.y):
		lineMappings[i] = i

	lineMappings_updated.emit(lineMappings)

func newSeedReset():
	AP.log("Resetting everything because new seed!")
	victory = false
	collectedItems.clear()
	missingLocations.clear()
	missingLines.clear()
	checkedLocations.clear()
	collectedAbilities.clear()
	activeAbilities.clear()
	allLineLocations.clear()
	missingPickups.clear()
	activeAbilities_updated.emit(activeAbilities)
	hintedRotateAbilities.clear()
	SignalBus.getSignal("restartGame").emit()

func getNextPiece() -> Dictionary:
	var numItems := collectedItems.size()
	while currentIndex < numItems:
		var stateItem := collectedItems[currentIndex]
		var item := CONSTANTS.ITEMS[stateItem.id]
		if item and item.tags.get("shape"):
			currentIndex += 1
			piecesLeft_updated.emit.call_deferred(countPieces(currentIndex))
			return {
				name = item.prettyName,
				stateItem = stateItem,
			}
		currentIndex += 1
	return {}
	piecesLeft_updated.emit.call_deferred(0)

func countPieces(from:int = 0) -> int:
	var total:int = 0
	for i in range(from, collectedItems.size()):
		var item := CONSTANTS.ITEMS[collectedItems[i].id]
		if item and item.tags.get("shape"):
			total += 1
	return total

func sendLocation(loc_id:int):
	# Send the location
	if Archipelago.conn:
		if missingLocations.get(loc_id, false):
			Archipelago.collect_location(loc_id)
			AP.log("Sending location: %s" % CONSTANTS.LOCATIONS[loc_id].prettyName)
		else:
			AP.log("Already sent: %s" % CONSTANTS.LOCATIONS[loc_id].prettyName)
	else:
		AP.log("Will send %s to server when reconnected." % CONSTANTS.LOCATIONS[loc_id].prettyName)

	missingLocations[loc_id] = false
	missingLocations_updated.emit(missingLocations)
	checkedLocations[loc_id] = true

func sendLine(lineIndex:int):
	if lineIndex >= allLineLocations.size():
		return

	AP.log("Send location id for line %d" % lineIndex)
	missingLines[lineIndex] = false
	missingLines_updated.emit(missingLines)
	sendLocation(allLineLocations[lineIndex])

func sendVictory():
	victory = true
	Archipelago.set_client_status(Archipelago.ClientStatus.CLIENT_GOAL)

#===== Events =====
func _on_connected(conn:ConnectionInfo, json:Dictionary):
	isJustConnected = true
	get_tree().create_timer(2, true).timeout.connect(set.bind("isJustConnected", false))
	Archipelago.set_deathlink(conn.slot_data.get("death_link", false) as bool)
	if "death_on_restart" in conn.slot_data:
		SignalBus.getSignal(
			"deathOnRestart_enabled" if conn.slot_data.get("death_on_restart", false)
			else "deathOnRestart_disabled"
		).emit()
	randomizeOrientations = conn.slot_data.get("randomize_orientations", false)
	conn.deathlink.connect(_on_deathlink)
	conn.obtained_item.connect(_on_obtained_item)
	conn.set_hint_notify(_on_on_hint_update)

	# Check min game version
	var minGameVersion:String = conn.slot_data.get("min_game_version", "0.1.0")
	if UserData.versionIsOlderThan(Config.versionNum, minGameVersion):
		var dialog:AcceptDialog = VERSION_WARNING_DIALOG_SCENE.instantiate()
		dialog.popup_exclusive_centered(self)
		dialog.dialog_text = "Game version {version} is too old for this slot data and may not work correctly! Target version is {minGameVersion} or newer!".format({
			version=Config.versionNum,
			minGameVersion=minGameVersion,
		})
		dialog.confirmed.connect(dialog.queue_free)

	# Create seed hash
	var _conn_ctx = hash("{seed}_{player_id}_{team_id}".format({
		seed=conn.seed_name,
		player_id=conn.player_id,
		team_id=conn.team_id
	}))

	# TODO: Check if this is a brand new seed, player, and team, and do a full reset
	if slotContextHash and slotContextHash != _conn_ctx: newSeedReset()

	slotContextHash = _conn_ctx
	goal = conn.slot_data.get("goal", -1)

	# Reset collected items
	collectedItems.clear()
	collectedAbilities.clear()
	allLineLocations.clear()
	missingPickupCoordinates.clear()
	missingLines.clear()
	missingPickups.clear()
	id_to_line.clear()
	id_to_pickupCoord.clear()
	
	var _checked:Dictionary[int,bool] = {}
	if json.has("checked_locations"):
		for loc:int in json["checked_locations"]:
			_checked[loc] = true

	var locsToCollect:Array[int] = []
	var _missingLocations_changed:bool = false
	var _allPickups:Array[int] = []
	for loc_id:int in conn.slot_locations:
		var loc_data:CONSTANTS.LocationData = CONSTANTS.LOCATIONS.get(loc_id)
		if loc_data:
			var checked:bool = _checked.get(loc_id, false)
			# Sync missingLocations and checkedLocations with server
			if not checked:
				if checkedLocations.get(loc_id, false):
					# We got this while offline and need to sync to server
					locsToCollect.append(loc_id)
					checked = true
				else:
					# This is a fresh load or different seed
					missingLocations[loc_id] = true
					_missingLocations_changed = true
			else:
				checkedLocations[loc_id] = true
				if missingLocations.get(loc_id, false):
					missingLocations[loc_id] = false
					_missingLocations_changed = true
			if loc_data.tags.get("line_clear", false):
				allLineLocations.append(loc_id)
			elif loc_data.tags.get("item_pickup", false):
				_allPickups.append(loc_id)
				if not checked:
					missingPickups.append(loc_id)
		else:
			AP.error("Got invalid location: id: {id}; name: {name}; You may be running an outdated version of the client!"
				.format({id=loc_id, name=conn.locations[loc_id].name})
			)
	
	# Sync with server
	if locsToCollect.size():
		Archipelago.collect_locations(locsToCollect)
	#
	allLineLocations.sort()
	_allPickups.sort()
	missingPickups.sort()

	# Create item pickup data
	var item_pickup_placements = conn.slot_data.get("item_pickup_placements", [])
	_allPickups.reverse()
	for index:int in item_pickup_placements:
		var vec:Vector2i = Vector2i(index % Board.BOUNDS.size.x, floor(index/Board.BOUNDS.size.x))
		var loc_id:Variant = _allPickups.pop_back()
		if loc_id != null and missingLocations.get(loc_id, false):
			missingPickupCoordinates[vec] = loc_id as int
			
	
	# Set up lookup tables
	for i:int in range(allLineLocations.size()):
		id_to_line[allLineLocations[i]] = i
		missingLines[i] = not _checked.get(allLineLocations[i], false)

	for k:Vector2i in missingPickupCoordinates:
		id_to_pickupCoord[missingPickupCoordinates.get(k,Vector2i())] = k

	if victory:
		sendVictory()

	if _missingLocations_changed:
		missingLocations_updated.emit(missingLocations)
		missingLines_updated.emit(missingLines)
		missingPickupCoordinates_updated.emit(missingPickupCoordinates)

func _on_deathlink(source: String, cause: String, json: Dictionary):
	if not cause: cause = "Died."
	notification_signal.emit("{source}: {cause}".format({source=source, cause=cause}), Color.RED, true)

func _on_obtained_item(item: NetworkItem):
	if not isJustConnected:
		var color = (
			Color.PURPLE if item.is_prog()
			else Color.ROYAL_BLUE if item.flags & AP.ItemClassification.USEFUL
			else Color.TOMATO if  item.flags & AP.ItemClassification.TRAP
			else Color.SKY_BLUE
		)
		if item.is_local():
			notification_signal.emit("You found your {item}!".format({item=item.get_name()}), color, false)
		else:
			notification_signal.emit("{source} sent you your {item}!"
				.format({source=Archipelago.conn.get_player_name(item.src_player_id), item=item.get_name()}), color, false
			)
	var si:StateItem = StateItem.fromNetworkItem(item)
	collectedItems.append(si)
	if item.id in CONSTANTS.ITEMS:
		# Detect shape streaks
		if CONSTANTS.ITEMS[item.id].tags.get("shape"):
			var streak:Streak
			# Get last shape in collectedItems and get its streak object if the same as this one 
			var index:int = collectedItems.size() - 2 # Get the one right before the one we just added
			while index >= 0 and collectedItems[index]:
				if collectedItems[index].id in CONSTANTS.ITEMS and CONSTANTS.ITEMS[collectedItems[index].id].tags.get("shape"):
					if collectedItems[index].id == si.id:
						streak = collectedItems[index].streak
					break
				index -= 1
			if not streak: streak = Streak.new()
			streak.size += 1
			si.streak = streak
		# Register collected ability
		if CONSTANTS.ITEMS[item.id].tags.get("ability"):
			if collectedAbilities.has(item.id):
				collectedAbilities[item.id] += 1
			else:
				collectedAbilities[item.id] = 1
			var prettyName = CONSTANTS.ITEMS[item.id].prettyName
			# TODO: Temp compatibility for Ghost Piece to count as Hold Slot
			if _holdSlotLegacyEnabled and prettyName == "Ghost Piece":
				prettyName = "Hold Slot"

			# Check if abilities have changed
			if activeAbilities.get(prettyName, 0) < collectedAbilities[item.id]:
				activeAbilities[prettyName] = collectedAbilities[item.id]
				activeAbilities_updated.emit(activeAbilities)
		elif CONSTANTS.ITEMS[item.id].tags.get("shape"):
			piecesLeft_updated.emit.call_deferred(countPieces(currentIndex))
	else:
		AP.error("Obtained invalid item: id: {id}; name: {name}; You may be running an outdated version of the client!"
			.format({id=item.id,name=item.get_name()})
		)
func _on_on_hint_update(hints: Array[NetworkHint]):
	if hints.size():
		AP.log("Got hints! %s" % hints.map(func(hint:NetworkHint): return hint.as_plain_string()))
	if Archipelago.conn:
		for hint:NetworkHint in hints:
			if hint.status == NetworkHint.Status.FOUND: continue
			if hint.item.dest_player_id == Archipelago.conn.player_id:
				# Only check hints for our abilities
				var item = CONSTANTS.ITEMS.get(hint.item.id)
				if item and item.tags.get("rotate"):
					hintedRotateAbilities[item.id] = StateItem.fromNetworkItem(hint.item)

func _on_remove_location(loc_id:int):
	var changed := missingLocations.erase(loc_id)
	if changed:
		checkedLocations[loc_id] = true
		missingLocations_updated.emit(missingLocations)
		if id_to_line.has(loc_id):
			missingLines[id_to_line[loc_id]] = false
			missingLines_updated.emit(missingLines)
		elif id_to_pickupCoord.has(loc_id):
			missingPickupCoordinates.erase(id_to_pickupCoord[loc_id])
			missingPickupCoordinates_updated.emit(missingPickupCoordinates)

func _on_Board_piece_requested(board:Board) -> void:
	var nextPiece:Dictionary = getNextPiece()
	if nextPiece:
		board.createPiece(nextPiece.get("name", ""), nextPiece.get("stateItem"))
	else:
		AP.log("Outta pieces!")

func _on_Board_game_started() -> void:
	reset()

func _on_Board_lines_cleared(lines:Array) -> void:
	assert(lines.size() < Board.BOUNDS.size.y)
	# Set lines as got
	for n:int in lines:
		gotLines[lineMappings[n]] = true
		sendLine(lineMappings[n])
		# Shift line mappings
		for i:int in range(n, Board.BOUNDS.size.y-1):
			lineMappings[i] = lineMappings[i + 1]
		lineMappings[Board.BOUNDS.size.y-1] += 1 

	lineMappings_updated.emit(lineMappings)

func _on_Board_item_pickedup(loc_id) -> void:
	AP.log("Picked up %s" % CONSTANTS.LOCATIONS[loc_id].prettyName)
	sendLocation(loc_id)

func _on_Board_lines_cleared_updated(num:int) -> void:
	_canUseDeathContext_NO_ROTATE = num >= LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT
	if not victory and goal > 0 and num >= goal:
		sendVictory()

func _on_Board_deathlink_earned(deathContext:DracominoUtil.DeathContext) -> void:
	if Archipelago.conn:
		var formatValues = {
			player = Archipelago.conn.get_player_name(),
			boardheight = str(Board.BOUNDS.size.y),
			totalpieces = str(countPieces(0)),
		}
		formatValues.merge(deathContext.formatValues, true)
		var contextTags = deathContext.contextTags.duplicate()
		var itemctx := deathContext.itemContext
		if itemctx:
			# Add context of last piece if any
			contextTags.append("LOCAL_ITEM" if itemctx.isLocal else "NONLOCAL_ITEM")
			var item := CONSTANTS.ITEMS[itemctx.id]
			formatValues.merge({
				item = (item.prettyName as String) if item else "Unknown Piece",
				sender = itemctx.senderName,
				location = itemctx.locationName,
				game = itemctx.gameName,
			})
			# Add context for having no rotate
			if _canUseDeathContext_NO_ROTATE and not (activeAbilities.get("Rotate Clockwise", 0) or activeAbilities.get("Rotate Counterclockwise", 0)):
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
			if itemctx.streak and itemctx.streak.size >= Streak.NOTABLE_THRESHOLD:
				contextTags.append("ITEM_STREAK")
				formatValues.merge({
					streaksize = itemctx.streak.size,
				})

		# Pick a template and generate a deathlink message
		var msg = DracominoUtil.generateDeathlinkMessage(deathContext.category, contextTags, formatValues) 
		Archipelago.conn.send_deathlink.call_deferred(msg)
		notification_signal.emit(msg, Color.RED, true)
		AP.log("%s%s: %s" % [msg, deathContext.category, contextTags])
