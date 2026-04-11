class_name DracominoHandler extends Node

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
		if seedFlagHolder:
			seedFlagHolder.setFlag("goal", value)
var slotContextHash:int:
	set(value):
		if slotContextHash == value:
			return
		slotContextHash = value
		slotContextHash_updated.emit(slotContextHash)
var seedFlagHolder:FlagHolder
var effectHandler:EffectHandler

var isJustConnected:bool = false
var VERSION_WARNING_DIALOG_SCENE:PackedScene = load("res://ui/versionwarning_dialog.tscn")

var LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT:int = 8 ## For death context
var _canUseDeathContext_NO_ROTATE:bool = false ## For death context
var _energySendBuffer:int = 0 ## Energy to send to server when reconnecting
var _effectBuffer:Array[StateItem] = [] ## Next traps to apply to next pieces

signal lineMappings_updated(mappings:Dictionary[int, int])
signal missingLines_updated(locs:Dictionary[int, bool])
signal notification_signal(notif:String, color:Color, force:bool)
signal missingPickupCoordinates_updated(map:Dictionary[Vector2i, int])
signal piecesLeft_updated(total:int)
signal goal_updated(goalnum:int)
signal slotContextHash_updated(ctx:int)
signal started()

class StateItem:
	var id:int
	var loc_id:int
	var sender_id:int
	var senderName:String = "someone"
	var locationName:String = "somewhere"
	var gameName:String = "game"
	var isLocal:bool = true
	var streak:Streak = null
	var used:bool = false ## Set to true when used as an effect, to prevent using again
	var data:CONSTANTS.ItemData:
		get:
			return CONSTANTS.ITEMS.get(id)
	static func fromNetworkItem(netItem:NetworkItem) -> StateItem:
		var si := StateItem.new()
		si.id = netItem.id
		si.loc_id = netItem.loc_id
		si.sender_id = netItem.src_player_id
		si.isLocal = netItem.src_player_id == 0 or netItem.is_local()
		if Archipelago.conn:
			si.senderName = Archipelago.conn.get_player_name(netItem.src_player_id)
			si.locationName = Archipelago.conn.get_gamedata_for_player(netItem.src_player_id).get_loc_name(netItem.loc_id)
			si.gameName = Archipelago.conn.get_game_for_player(netItem.src_player_id)
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

class Streak:
	var size:int = 0
	static var NOTABLE_THRESHOLD:int = 4

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
	DracominoCommandManager.addCommand("GETITEM", giveItemCommand).setArgHint("name")
	DracominoCommandManager.addCommand("TRIGGEREFFECT", triggerEffectCommand).setArgHint("name")

	# Set up trap link signal
	SignalBus.getSignal("stateflag_set", "trap_link").connect(Archipelago.set_traplink.bind(true))
	SignalBus.getSignal("stateflag_cleared", "trap_link").connect(Archipelago.set_traplink.bind(false))

	# Make the EnergyLink tag appear when energy link is enabled
	SignalBus.getSignal("stateflag_set", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", true))
	SignalBus.getSignal("stateflag_cleared", "energy_link").connect(Archipelago.set_tag.bind("EnergyLink", false))

#===== Functions =====
func reset():
	currentIndex = 0
	seedFlagHolder.count("shapes_left", "subtracted", 0)
	gotLines.clear()
	lineMappings.clear()
	# Fill visible line mappings
	for i in range(Board.BOUNDS.size.y):
		lineMappings[i] = i

	lineMappings_updated.emit(lineMappings)

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
	hintedRotateAbilities.clear()
	resetSeedFlagHolder()
	# Reset when everything is loaded
	await started
	SignalBus.getSignal("restartGame").emit()

func resetSeedFlagHolder():
	if seedFlagHolder: seedFlagHolder.queue_free()
	seedFlagHolder = FlagHolder.new(FlagHolder.PRIORITY.WORLD)
	FlagManager.HANDLERS.WORLD.setAsFlagHolder(seedFlagHolder)
	add_child(seedFlagHolder)

func getNextPiece() -> Dictionary:
	var numItems := collectedItems.size()
	# Iterate through all items
	while currentIndex < numItems:
		var stateItem := collectedItems[currentIndex]
		var item := CONSTANTS.ITEMS[stateItem.id]
		if item:
			match item.type:
				"shape":
					# Apply any effects from the effect buffer first
					var effects:Dictionary[StringName, StateItem] = {}
					for fx:StateItem in _effectBuffer.duplicate():
						var fx_item := CONSTANTS.ITEMS[fx.id]
						match fx_item.type:
							"on_lock", "modifier", "on_spawn":
								if not effects.get(fx_item.type):
									effects[fx_item.type] = fx
									_effectBuffer.erase(fx)
					currentIndex += 1
					seedFlagHolder.count("shapes_left", "subtracted", -1, true)
					return {
						name = item.prettyName,
						stateItem = stateItem,
						effects = effects,
					}
				"on_lock", "modifier", "on_spawn":
					_effectBuffer.append(stateItem)
		currentIndex += 1
	return {}

func sendLocation(loc_id:int):
	# Send the location
	if Archipelago.conn and missingLocations.get(loc_id, false):
		Archipelago.collect_location(loc_id)
		print("Sending location: ", CONSTANTS.LOCATIONS[loc_id].prettyName)
	elif Archipelago.conn:
		print("Already sent: ", CONSTANTS.LOCATIONS[loc_id].prettyName)
	else:
		print("Will send ", CONSTANTS.LOCATIONS[loc_id].prettyName, " to server when reconnected.")
	
	missingLocations[loc_id] = false
	checkedLocations[loc_id] = true

func sendLine(lineIndex:int):
	if lineIndex >= allLineLocations.size():
		return

	print("Send location id for line ", lineIndex)
	missingLines[lineIndex] = false
	missingLines_updated.emit(missingLines)
	sendLocation(allLineLocations[lineIndex])

func sendVictory():
	victory = true
	Archipelago.set_client_status(Archipelago.ClientStatus.CLIENT_GOAL)

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
	var upgradeResult:Dictionary = {
		retrofitted = [],
	}
	if UserData.versionIsOlderThan(generatedVersion, "0.2.2"):
		var RETROFITTED_ABILITIES:Array[StringName] = [
			"kick",
			"vertical_shove",
			"lock_delay",
		]
		for internalName:StringName in RETROFITTED_ABILITIES:
			var id:Variant = CONSTANTS.ITEM_NAME_TO_ID.get(internalName)
			var item := CONSTANTS.ITEMS[id] if id != null else null
			if item:
				collectedAbilities[item.id] = 1
				if not seedFlagHolder.isFlagSet(item.internalName):
					seedFlagHolder.count(item.internalName, "collected", 1)
					upgradeResult.retrofitted.append(item.prettyName)
		
		# Set legacy colors
		seedFlagHolder.setFlag("legacy_piece_colors")

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
	var item:StateItem = resolveItem(option)
	if item and item.data:
		var success:bool = false
		match item.data.type:
			"on_lock", "on_spawn":
				success = effectHandler.triggerEffectImmediately(item)
			"modifier": pass
			_:
				var msg:String = "%s is not an effect"%item.data.prettyName
				printerr("DracominoHandler.triggerEffectCommand: ", msg)
				notification_signal.emit("Trigger effect failed: "+msg, CONSTANTS.COLOR.ERROR, true)
				return
		if success:
			notification_signal.emit("Triggering effect: %s"%item.data.prettyName, CONSTANTS.COLOR.SPECIAL, true)
		else:
			notification_signal.emit("Trigger effect failed: %s does not meet conditions"%item.data.prettyName, CONSTANTS.COLOR.ERROR, true)

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
		print("There is no alias for ", trapname)
		return ""

	for alias in trapsToTrigger:
		var item:StateItem = resolveItem(alias)
		item.senderName = source
		item.isLocal = false
		if item and item.data:
			var success:bool = false
			match item.data.type:
				"on_lock", "on_spawn":
					effectHandler.tryToTriggerEffect(item, true, ["all"])
					triggeredTraps.append(CONSTANTS.TRAP_LINK_CONVERTS.get(alias, alias))
				"modifier": pass
				_:
					print("DracominoHandler.triggerTrapLinkTrap: there is not an effect called ", alias)
	
	if triggeredTraps.size():
		return " and ".join(triggeredTraps)
	print("No traps were triggered: ", trapsToTrigger)
	return ""


func giveItem(item:StateItem):
	if not item: return
	collectedItems.append(item)
	if item.data:
		match item.data.type:
			# Detect shape streaks
			"shape":
				seedFlagHolder.count("shapes_left", "collected", 1, true)
				seedFlagHolder.count("shapes", item.data.internalName, 1, true)
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
			# Register collected ability
			"ability":
				if collectedAbilities.has(item.id):
					collectedAbilities[item.id] += 1
				else:
					collectedAbilities[item.id] = 1
				var prettyName = item.data.prettyName

				# Add flag for ability
				seedFlagHolder.count(item.data.internalName, "collected", collectedAbilities[item.id])

				# Keep track of rotate abilities collected
				if item.data.tags.get("rotate"):
					seedFlagHolder.count("rotate", item.data.internalName, 1)
			# Trigger effects
			"on_lock", "on_spawn":
				if not isJustConnected:
					var result = effectHandler.tryToTriggerEffect(item, false)
					if result and FlagManager.isFlagSet("trap_link"):
						var trapLinkAlias:String = CONSTANTS.TRAP_ALIASES.get(item.data.internalName, "")
						if trapLinkAlias and Archipelago.conn:
							Archipelago.conn.send_traplink(trapLinkAlias)
							print("Sending trap: ", trapLinkAlias)


	else:
		print("Obtained invalid item: id: {id}; name: {name}; You may be running an outdated version of the client!"
			.format({id=item.id,name=item.get_name()})
		)

#===== Events =====
func _on_connected(conn:ConnectionInfo, json:Dictionary):
	isJustConnected = true
	get_tree().create_timer(2, true).timeout.connect(set.bind("isJustConnected", false))
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
	#
	var randomizeOrientations = conn.slot_data.get("randomize_orientations", false)
	if randomizeOrientations:
		seedFlagHolder.setFlag("randomize_orientations")
	else:
		seedFlagHolder.clearFlag("randomize_orientations")
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

	var locsToCollect:Array[int] = []
	var _missingLocations_changed:bool = false
	var _allPickups:Array[int] = []
	for loc_id:int in conn.slot_locations:
		var loc_data:CONSTANTS.LocationData = CONSTANTS.LOCATIONS.get(loc_id)
		if loc_data:
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
					missingLocations[loc_id] = false
					_missingLocations_changed = true
			if loc_data.tags.get("line_clear", false):
				allLineLocations.append(loc_id)
			elif loc_data.tags.get("item_pickup", false):
				_allPickups.append(loc_id)
				if not checked:
					missingPickups.append(loc_id)
		else:
			printerr("Got invalid location: id: {id}; name: {name}; You may be running an outdated version of the client!"
				.format({id=loc_id, name=conn.locations[loc_id].name})
			)
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
		missingLines[i] = missingLocations.get(allLineLocations[i], false)

	for k:Vector2i in missingPickupCoordinates:
		id_to_pickupCoord[missingPickupCoordinates.get(k,Vector2i())] = k

	if victory:
		sendVictory()

	# Send new state to board
	if _missingLocations_changed:
		missingLines_updated.emit(missingLines)
		missingPickupCoordinates_updated.emit(missingPickupCoordinates)

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

func _on_deathlink(source: String, cause: String, json: Dictionary):
	if not cause: cause = "Died."
	notification_signal.emit("{source}: {cause}".format({source=source, cause=cause}), CONSTANTS.COLOR.DEATH, true)

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
	if hints.size():
		print("Got hints! ", hints.map(func(hint:NetworkHint): return hint.as_plain_string()))
	if Archipelago.conn:
		for hint:NetworkHint in hints:
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
		checkedLocations[loc_id] = true
		if id_to_line.has(loc_id):
			missingLines[id_to_line[loc_id]] = false
			missingLines_updated.emit(missingLines)
		elif id_to_pickupCoord.has(loc_id):
			missingPickupCoordinates.erase(id_to_pickupCoord[loc_id])
			missingPickupCoordinates_updated.emit(missingPickupCoordinates)

func _on_Board_pieces_requested(callback:Callable, num:int) -> void:
	for i:int in range(num):
		var nextPiece:Dictionary = getNextPiece()
		if nextPiece:
			callback.call(nextPiece.get("name", ""), nextPiece.get("stateItem"), nextPiece.get("effects", {}))
		else:
			print("Outta pieces!")
			break;

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
	
	# Send mana/energy
	var manaEarned:float = lines.size() * Board.BOUNDS.size.x * CONSTANTS.MANA_PER_BLOCK
	var sharedMana:float = 0.0
	if FlagManager.isFlagSet("energy_link"):
		sharedMana = manaEarned * CONSTANTS.ENERGY_LINK_SHARE
		sendEnergy(round(sharedMana * CONSTANTS.MANA_TO_ENERGY_RATIO))
	seedFlagHolder.count("mana", "earned", manaEarned - sharedMana, true)

func _on_Board_item_pickedup(loc_id) -> void:
	print("Picked up ", CONSTANTS.LOCATIONS[loc_id].prettyName)
	sendLocation(loc_id)

func _on_Board_lines_cleared_updated(num:int) -> void:
	# Make NO_ROTATE death context only happen when you're putting the effort
	_canUseDeathContext_NO_ROTATE = num >= LINE_THRESHOLD_FOR_NO_ROTATE_DEATH_CONTEXT
	# Send victory if reached goal
	if not victory and goal > 0 and num >= goal:
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
			if itemctx.streak and itemctx.streak.size >= Streak.NOTABLE_THRESHOLD:
				contextTags.append("ITEM_STREAK")
				formatValues.merge({
					streaksize = itemctx.streak.size,
				})

		# Pick a template and generate a deathlink message
		var msg = DracominoUtil.generateDeathlinkMessage(deathContext.category, contextTags, formatValues) 
		Archipelago.conn.send_deathlink.call_deferred(msg)
		notification_signal.emit(msg, CONSTANTS.COLOR.DEATH, true)
		print(msg, deathContext.category, ": ", contextTags)
