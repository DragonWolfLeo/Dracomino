extends Node

signal signal_self(flag:Variant)
signal error()

var SIGNALS:Dictionary[String, SignalDistributor] = {
	signal_self = SignalDistributor.new(signal_self),
}

class SignalHolder:
	signal triggered()

class SignalDistributor:
	var registeredSignals:Dictionary[Variant, SignalHolder] = {}

	func _init(_signal:Signal) -> void:
		_signal.connect(_on_signal)

	func getSignal(flag:Variant) -> Signal:
		if !registeredSignals.has(flag):
			registeredSignals[flag] = SignalHolder.new()
		return registeredSignals[flag].triggered
	
	func _on_signal(flag:Variant):
		if registeredSignals.has(flag):
			registeredSignals[flag].triggered.emit()

# === Functions ===
## Split a signal that emits a value into a distributor that can make individual signals for specific values
func registerSignalDistributor(masterSignal:Signal, key:Variant) -> void:
	if SIGNALS.get(key):
		printerr("SignalBus.registerSignalDistributor: Already have key "+key)
		return
	
	SIGNALS[key] = SignalDistributor.new(masterSignal)

## Get or create a custom signal. Avoid connecting to singleton objects from a non-singleton.
func getSignal(key:StringName = "", flag:Variant = null) -> Signal:
	if key:
		if flag:
			var sd:SignalDistributor = SIGNALS.get(key)
			if sd:
				return sd.getSignal(flag)
			else:
				printerr("getSignal: Could not get signal distributor for key {key}".format({key=key}))
		else:
			return SIGNALS.signal_self.getSignal(key)
	elif flag is String or flag is StringName:
		return SIGNALS.signal_self.getSignal(flag)
	return error
