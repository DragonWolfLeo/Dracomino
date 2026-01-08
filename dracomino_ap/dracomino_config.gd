class_name DracominoConfigManager extends APConfigManager

const DRACOMINO_CONFIG_VERSION := 1
var ip: String = "" :
	set(val):
		if val != ip:
			ip = val
			save_cfg()
			config_changed.emit()
var port: String = "" :
	set(val):
		if val != port:
			port = val
			save_cfg()
			config_changed.emit()
var slot: String = "" :
	set(val):
		if val != slot:
			slot = val
			save_cfg()
			config_changed.emit()

func update_credentials(creds: APCredentials) -> void:
	_pause_saving = true
	ip = creds.ip
	port = creds.port
	slot = creds.slot
	_pause_saving = false
	save_cfg()

func _load_cfg(file: FileAccess) -> bool:
	if not super(file):
		return false
	var _vers := file.get_32()
	ip = file.get_pascal_string()
	port = file.get_pascal_string()
	slot = file.get_pascal_string()
	Archipelago.creds.update(ip, port, slot, "")
	return true

func _save_cfg(file: FileAccess) -> void:
	super(file)
	file.store_32(DRACOMINO_CONFIG_VERSION)
	file.store_pascal_string(ip)
	file.store_pascal_string(port)
	file.store_pascal_string(slot)
