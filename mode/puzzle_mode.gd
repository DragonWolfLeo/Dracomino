extends Mode

@onready var linesLabel:Label = %LinesLabel
@onready var piecesLabel:Label = %PiecesLabel

func _ready() -> void:
	super()
	SignalBus.getSignal("stateflag_changed", "goal").connect(updateLineClearedLabel, CONNECT_DEFERRED)
	SignalBus.getSignal("stateflag_changed", "lines_cleared").connect(updateLineClearedLabel, CONNECT_DEFERRED)
	SignalBus.getSignal("stateflag_changed", "shapes_left").connect(updatePiecesLeft, CONNECT_DEFERRED)

func updateLineClearedLabel():
	if linesLabel:
		linesLabel.text = "Lines: {num} / {goal}".format({
			num=FlagManager.getIntFlagValue("lines_cleared"),
			goal=FlagManager.getIntFlagValue("goal")
		})

func updatePiecesLeft() -> void:
	if piecesLabel:
		piecesLabel.text = "Pieces Left: {total}".format({total=FlagManager.getTotalCountAmount("shapes_left")})