extends Sprite2D

enum {
	IDLE_FRAME,
	CHARGE_FRAME,
	RELEASE_FRAME,
}

signal piece_caught(piece:Piece)
signal nothing_caught()

@export var camera:Node2D

@onready var staminaBar:ProgressBar = %FishingStaminaBar
@onready var fishingHook:FishingHook = %FishingHook
@onready var fishingRodMarker_idle:Marker2D = %FishingRodMarker_Idle
@onready var fishingRodMarker_charge:Marker2D = %FishingRodMarker_Charge
@onready var fishingLine:Line2D = %FishingLine

@onready var FISHING_HOOK_STARTING_POSITION = fishingHook.position

var MIN_STAMINA_STRENGTH:float = 0.2
var RETRIEVE_DIST_SQ:float = 50*50
var THROW_VELOCITY:Vector2 = Vector2(150, -150)
var REEL_ACCELERATION:float = 20
var REEL_DURATION:float = 3.0
var CHARGE_DURATION:float = 1.5
var RESET_DURATION:float = 0.3
var FISHGET_DURATION:float = 3.0

var tween:Tween
var fishReelTween:Tween
var fishCaughtTween:Tween:
	set(value):
		fishCaughtTween = value
		set_process_input(fishCaughtTween == null)
var currentCharge:float = 0.0:
	set(value):
		currentCharge = value
		if staminaBar:
			staminaBar.value = value
			staminaBar.visible = value > 0

var casted:bool = false:
	set(value):
		casted = value
		if fishingHook:
			fishingHook.set_physics_process(casted)

# === Virtuals ===
func _ready() -> void:
	reset()
	var mode:Mode = DracominoUtil.getParentMode(self)
	if mode:
		mode.mode_enabled.connect(reset)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cast"):
		if casted:
			if fishingHook.position.distance_squared_to(fishingRodMarker_idle.position) < RETRIEVE_DIST_SQ:
				retrieve()
			else:
				startReel()
		else:
			startCharge()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("cast"):
		if casted:
			stopReel()
		else:
			releaseCast()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	drawFishingLine()

# === Functions ===
func reset(immediate:bool = true):
	if tween: tween.kill()
	if fishCaughtTween: fishCaughtTween.kill()
	staminaBar.hide()
	staminaBar.value = 0
	casted = false
	currentCharge = 0
	frame = IDLE_FRAME
	if immediate:
		fishingHook.position = FISHING_HOOK_STARTING_POSITION
	else:
		tween = create_tween()
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(fishingHook, "position", FISHING_HOOK_STARTING_POSITION, RESET_DURATION).from_current()

func retrieve():
	var hooked:FishPiece = fishingHook.hooked
	fishingHook.hooked = null
	if hooked and hooked.piece:
		if fishCaughtTween: fishCaughtTween.kill()
		fishCaughtTween = hooked.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fishCaughtTween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_parallel()
		fishCaughtTween.tween_property(hooked, "position", camera.position if camera else position, 1.5).from_current()
		fishCaughtTween.tween_property(hooked, "scale", Vector2(4,4), 1.5).from_current()
		fishCaughtTween.set_parallel(false)
		fishCaughtTween.tween_property(hooked, "rotation_degrees", 15, 0.2).from_current().set_ease(Tween.EASE_IN)
		fishCaughtTween.tween_property(hooked, "rotation_degrees", 0, 0.15).from(15).set_ease(Tween.EASE_IN)
		fishCaughtTween.tween_property(hooked, "rotation_degrees", -30, 0.15).from(0).set_ease(Tween.EASE_OUT)
		fishCaughtTween.tween_property(hooked, "rotation_degrees", 0, 0.25).from(-30).set_ease(Tween.EASE_IN_OUT)
		hooked.z_index = 3
		SoundManager.play("fishget")
		DialogueManager.showNotification("You just caught a {name}!".format({name = hooked.piece.prettyName}))
		await DialogueManager.dialogue_ended
		fishCaughtTween.kill()
		fishCaughtTween = null
		# Since we waited, check again the fish is still there
		if hooked:
			piece_caught.emit(hooked.piece)
		else:
			nothing_caught.emit()
	else:
		nothing_caught.emit()
	reset(false)

func startCharge():
	if frame == CHARGE_FRAME:
		return
	if tween: tween.kill()
	frame = CHARGE_FRAME
	casted = false
	fishingHook.position = fishingRodMarker_charge.position + FISHING_HOOK_STARTING_POSITION - fishingRodMarker_idle.position
	tween = create_tween()
	tween.tween_method(setCharge, 0.0, 1.0, CHARGE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

func setCharge(value:float):
	currentCharge = value

func startReel():
	if tween: tween.kill()
	frame = CHARGE_FRAME
	tween = create_tween()
	tween.tween_method(reel, 1.0, 0.0, REEL_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	if fishingHook.hooked:
		var hooked:FishPiece = fishingHook.hooked
		if fishReelTween: fishReelTween.kill()
		fishReelTween = hooked.create_tween().set_trans(Tween.TRANS_QUAD)
		fishReelTween.tween_property(hooked, "rotation_degrees", 10, 0.1).from_current().set_ease(Tween.EASE_IN)
		fishReelTween.tween_property(hooked, "rotation_degrees", 0, 0.05).from(10).set_ease(Tween.EASE_IN)
		fishReelTween.tween_property(hooked, "rotation_degrees", -10, 0.05).from(0).set_ease(Tween.EASE_OUT)
		fishReelTween.tween_property(hooked, "rotation_degrees", 0, 0.1).from(-10).set_ease(Tween.EASE_IN_OUT)

func reel(amount:float):
	fishingHook.velocity += fishingHook.position.direction_to(fishingRodMarker_idle.position) * REEL_ACCELERATION * amount

func stopReel():
	if tween: tween.kill()
	frame = IDLE_FRAME

func releaseCast():
	if currentCharge == 0:
		return
	if tween: tween.kill()
	if currentCharge < MIN_STAMINA_STRENGTH:
		frame = IDLE_FRAME
		fishingHook.position = FISHING_HOOK_STARTING_POSITION
	else:
		frame = RELEASE_FRAME
		tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(set.bind("frame", IDLE_FRAME))
		fishingHook.velocity = THROW_VELOCITY * Vector2(currentCharge, 1)
		fishingHook.position = fishingRodMarker_charge.position + FISHING_HOOK_STARTING_POSITION - fishingRodMarker_idle.position
		casted = true
	currentCharge = 0

func drawFishingLine():
	fishingLine.clear_points()
	var marker:Marker2D = fishingRodMarker_charge if frame == CHARGE_FRAME else fishingRodMarker_idle
	fishingLine.add_point(marker.position)
	fishingLine.add_point(fishingHook.position)
