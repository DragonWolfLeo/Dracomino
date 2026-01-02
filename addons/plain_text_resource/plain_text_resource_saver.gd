@tool
extends ResourceFormatSaver
class_name PlainTextFormatSaver

func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	return PackedStringArray(["txt"])

func _recognize(resource: Resource) -> bool:
	return resource is PlainTextResource

func _save(resource: Resource, path: String, flags: int) -> Error:
	var file = FileAccess.open(path,FileAccess.WRITE)
	
	if !file:
		var err = FileAccess.get_open_error()
		printerr('Can\'t write file: "%s"! code: %d.' % [path, err])
		return err
	
	file.store_string(resource.get("text"))
	return OK
