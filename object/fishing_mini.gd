extends Sprite2D

enum {
	IDLE_FRAME,
	CHARGE_FRAME,
	RELEASE_FRAME,
}

signal piece_caught(piece:Piece)
signal nothing_caught()

@onready var staminaBar:ProgressBar = %FishingStaminaBar
@onready var fishingHook:FishingHook = %FishingHook
@onready var fishingRodMarker_idle:Marker2D = %FishingRodMarker_Idle
@onready var fishingRodMarker_charge:Marker2D = %FishingRodMarker_Charge
@onready var fishingLine:Line2D = %FishingLine

@onready var FISHING_HOOK_STARTING_POSITION = fishingHook.position

var MIN_STAMINA_STRENGTH:float = 0.2
var RETRIEVE_DIST_SQ:float = 50*50

var tween:Tween
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
func reset():
	if tween: tween.kill()
	staminaBar.hide()
	staminaBar.value = 0
	fishingHook.position = FISHING_HOOK_STARTING_POSITION
	casted = false
	currentCharge = 0
	frame = IDLE_FRAME

func retrieve():
	var hooked:FishPiece = fishingHook.hooked
	fishingHook.hooked = null
	if hooked and hooked.piece:
		piece_caught.emit(hooked.piece)
	else:
		nothing_caught.emit()
	reset()

func startCharge():
	if tween: tween.kill()
	frame = CHARGE_FRAME
	casted = false
	fishingHook.position = fishingRodMarker_charge.position + FISHING_HOOK_STARTING_POSITION - fishingRodMarker_idle.position
	tween = create_tween()
	tween.tween_method(setCharge, 0.0, 1.0, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func setCharge(value:float):
	currentCharge = value

func startReel():
	if tween: tween.kill()
	frame = CHARGE_FRAME
	tween = create_tween()
	tween.tween_method(reel, 1.0, 0.0, 3.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func reel(amount:float):
	fishingHook.velocity += fishingHook.position.direction_to(fishingRodMarker_idle.position) * 20 * amount

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
		fishingHook.velocity = Vector2(150*currentCharge, -150)
		fishingHook.position = fishingRodMarker_charge.position + FISHING_HOOK_STARTING_POSITION - fishingRodMarker_idle.position
		casted = true
	currentCharge = 0

func drawFishingLine():
	fishingLine.clear_points()
	var marker:Marker2D = fishingRodMarker_charge if frame == CHARGE_FRAME else fishingRodMarker_idle
	fishingLine.add_point(marker.position)
	fishingLine.add_point(fishingHook.position)
