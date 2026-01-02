extends Node

signal signal_self(flag:String)
signal error()

var SIGNALS:Dictionary[String, SignalDistributor] = {
	signal_self = SignalDistributor.new(signal_self),
}

class SignalHolder:
	signal triggered()

class SignalDistributor:
	var registeredSignals:Dictionary[StringName, SignalHolder] = {}

	func _init(_signal:Signal) -> void:
		_signal.connect(_on_signal)

	func getSignal(flag:StringName) -> Signal:
		flag = flag.to_lower()
		if !registeredSignals.has(flag):
			registeredSignals[flag] = SignalHolder.new()
		return registeredSignals[flag].triggered
	
	func _on_signal(flag:StringName):
		flag = flag.to_lower()
		if registeredSignals.has(flag):
			registeredSignals[flag].triggered.emit()

### Functions
func registerSignalDistributor(masterSignal:Signal, key:Variant):
	if SIGNALS.get(key):
		printerr("SignalBus.registerSignalDistributor: Already have key "+key)
		return
	
	SIGNALS[key] = SignalDistributor.new(masterSignal)

func getSignal(key:StringName = "", flag:StringName = "") -> Signal:
	if key:
		if flag:
			var sd:SignalDistributor = SIGNALS.get(key)
			if sd:
				return sd.getSignal(flag)
			else:
				printerr("getSignal: Could not get signal distributor for key {key}".format({key=key}))
		else:
			return SIGNALS.signal_self.getSignal(key)
	elif flag:
		return SIGNALS.signal_self.getSignal(flag)
	return error
