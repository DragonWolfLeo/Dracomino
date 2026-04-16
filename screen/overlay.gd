class_name Overlay extends CanvasLayer

signal fader_full()
signal fader_finished()
signal fader_continued()
signal focusmask_pressed()
signal imageoverlay_animation_finished()
signal imageoverlay_hidden()
signal imageoverlay_appearing()
signal imageoverlay_shifted()
signal cutscene_appearing()

static var overlay:Overlay
static var fadeActive:bool = false
var cutscene:Control = null
@onready var imageOverlay := $ImageOverlay
@onready var imageOffset := $ImageOverlay/ImageOffset
@onready var textureRect:TextureRect = $ImageOverlay/ImageOffset/ImageContainer/TextureRect
@onready var blackFader := $Faders/Black
@onready var cutsceneContainer := $CutsceneContainer
@onready var objectOverlay := $ObjectOverlay
@onready var objectContainer := $ObjectOverlay/ObjectContainer

func _enter_tree() -> void:
	overlay = self

func _ready():
	imageOverlay.hide()
	objectOverlay.hide()

static func doFade(fadeOutTime = 0.5, fadeInTime = 0.5):
	if not overlay: return
	doFadeOut(fadeOutTime)
	await overlay.fader_full
	doFadeIn.call_deferred(fadeInTime)

static func doFadeOut(fadeOutTime = 0.5):
	if not overlay: return
	overlay.blackFader.show()
	fadeActive = true
	var tween = overlay.create_tween()
	tween.tween_property(overlay.blackFader,"modulate",Color(0,0,0,1),fadeOutTime).from(Color(0,0,0,0))
	tween.tween_callback(overlay._midFade)

static func doFadeIn(fadeInTime = 0.5):
	if not overlay: return
	overlay.blackFader.show()
	var tween = overlay.create_tween()
	tween.tween_property(overlay.blackFader,"modulate",Color(0,0,0,0),fadeInTime).from(Color(0,0,0,1))
	tween.tween_callback(overlay._finishFade)
		
func _midFade():
	fader_full.emit()
	
func _finishFade():
	blackFader.hide()
	fader_finished.emit()
	fadeActive = false

func activateFocusMask():
	var focusMask:Control = $FocusMask
	focusMask.show()
	focusMask.grab_focus()

func _on_focus_mask_gui_input(event:InputEvent):
	if (event.is_action_pressed("mouse1") 
	or event.is_action_pressed("ui_accept") 
	or event.is_action_pressed("ui_cancel")
	or event.is_action_pressed("back")
	or (event is InputEventScreenTouch and event.is_pressed())
	):
		get_viewport().set_input_as_handled()
		focusmask_pressed.emit()
		$FocusMask.hide()

static func showImageByName(imageName:String):
	if not overlay: return
	# If empty parameters, then hide image
	if !imageName.length():
		hideImage()
		return
	
	# Get image resource
	var photoName = "photo_" + imageName
	
	var resName:String = "res://resource/"+photoName+".tres"
	if ResourceLoader.exists(resName): 
		overlay.showImage(load(resName))
	else:
		printerr("Overlay.showImageByName: %s does not exist"%resName)

func showImage(tex:Texture2D = null, immediate:bool = false):
	if tex:		
		# Do the overlay
		textureRect.texture = tex
		# $ImageOverlay/ImageOffset/ImageContainer.self_modulate.a = 1 if item.border else 0
		# $ImageOverlay/ImageOffset/ImageContainer/TextureRect/ColorRect.visible = item.border
		if !immediate:
			var tween = imageOverlay.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(imageOverlay, "modulate", Color(1,1,1,1), 0.3).from(Color(1,1,1,0))
			tween.tween_property(imageOverlay, "position", Vector2(0,0), 0.4).from(Vector2(-200,0))
			imageoverlay_appearing.emit()
		else:
			imageOverlay.position = Vector2.ZERO
			imageOverlay.modulate = Color(1,1,1,1)
		imageOverlay.show()
	elif !immediate:
		var tween = imageOverlay.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(imageOverlay, "modulate", Color(1,1,1,0), 0.3).from_current()
		tween.tween_property(imageOverlay, "position", Vector2(200,0), 0.3).from_current()
		tween.tween_callback(_hideAndEmit).set_delay(0.4)
		tween.finished.connect(_hideAndEmit, CONNECT_ONE_SHOT)
		imageoverlay_hidden.connect(tween.kill) # Needed to stop some weirdness
		imageoverlay_appearing.connect(tween.kill) # Needed to stop some weirdness
	else:
		imageoverlay_hidden.emit()
		imageOverlay.hide()

static func hideImage(immediate:bool = false):
	if not overlay: return
	overlay.showImage(null, immediate)
	
static func shiftImageOverlay(amount:Vector2 = Vector2.ZERO, immediate:bool = false):
	if not overlay: return
	if immediate:
		overlay.imageOffset.position = amount
		overlay.imageoverlay_shifted.emit()
	else:
		overlay.imageoverlay_shifted.emit()
		var tween = overlay.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(overlay.imageOffset, "position", amount, 0.25).from(overlay.imageOffset.position)
		overlay.imageoverlay_shifted.connect(tween.kill)
	
func _hideAndEmit():
	imageOverlay.hide()
	imageoverlay_animation_finished.emit()
	imageoverlay_hidden.emit()

static func showObjectByName(objectName:String):
	if not overlay: return
	# If empty parameters, then hide object
	if !objectName.length():
		hideImage()
		return
	
	# Get object resource	
	var resName:String = "res://object/overlayobject/"+objectName+".tscn"
	if ResourceLoader.exists(resName):
		var objectScene:Resource = load(resName)
		if objectScene is PackedScene:
			overlay.showObject(objectScene.instantiate())
		else:
			printerr("Overlay.showObjectByName: %s is not a PackedScene"%resName)
	else:
		printerr("Overlay.showObjectByName: %s does not exist"%resName)

func showObject(control:Control = null, immediate:bool = false):
	if control:
		objectContainer.add_child(control)
		imageoverlay_hidden.connect(control.queue_free)
		if !immediate:
			var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(objectOverlay, "modulate", Color(1,1,1,1), 0.3).from(Color(1,1,1,0))
			tween.tween_property(objectOverlay, "position", Vector2(0,0), 0.4).from(Vector2(-200,0))
			imageoverlay_appearing.emit()
		else:
			objectOverlay.position = Vector2.ZERO
			objectOverlay.modulate = Color(1,1,1,1)
		objectOverlay.show()
	elif !immediate:
		var tween = objectOverlay.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(objectOverlay, "modulate", Color(1,1,1,0), 0.3).from_current()
		tween.tween_property(objectOverlay, "position", Vector2(200,0), 0.3).from_current()
		tween.finished.connect(objectOverlay.hide, CONNECT_ONE_SHOT)
		imageoverlay_hidden.connect(tween.kill) # Needed to stop some weirdness
		imageoverlay_appearing.connect(tween.kill) # Needed to stop some weirdness
	else:
		imageoverlay_hidden.emit()
		objectOverlay.hide()

static func hideObject(immediate:bool = false):
	if not overlay: return
	overlay.showObject(null, immediate)
	
func isActive():
	return fadeActive
	
func showCutscene(packed:PackedScene):
	cutscene = packed.instantiate()
	if !cutscene: return
	cutscene.modulate.a = 0
	cutsceneContainer.add_child(cutscene)
	var tween = create_tween()
	tween.tween_property(cutscene, "modulate", Color.WHITE,0.5).from_current()
	cutscene_appearing.emit()
	
static func showCutsceneByName(cutsceneName:String):
	if not overlay: return
	overlay.clearCutscene()
	var template = {cutsceneName = cutsceneName}
	var resPath = "res://cutscene/{cutsceneName}.tscn".format(template)
	if ResourceLoader.exists(resPath):
		overlay.showCutscene(load(resPath) as PackedScene)
	else:
		printerr("Error! Cutscene {cutsceneName} doesn't exist!".format(template))
	
static func hideCutscene():
	if not overlay: return
	if !overlay.cutscene: return
	var tween = overlay.create_tween()
	tween.tween_property(overlay.cutscene, "modulate", Color(1,1,1,0),0.5).from_current()
	tween.tween_callback(overlay.clearCutscene)
	overlay.cutscene_appearing.connect(tween.kill)
	
func clearCutscene():
	for child in cutsceneContainer.get_children():
		child.queue_free()
	cutscene = null
