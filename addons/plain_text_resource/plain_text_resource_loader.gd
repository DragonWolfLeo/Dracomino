@tool
extends ResourceFormatLoader

class_name PlainTextFormatLoader

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["txt"])

func _get_resource_type(path: String) -> String:
	var ext = path.get_extension().to_lower()
	if ext == "txt":
		return "PlainTextResource"
	
	return ""

func _handles_type(typename: StringName) -> bool:
	return ClassDB.is_parent_class(typename, "Resource")

func _load(path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int):
	var res := PlainTextResource.new()
	
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		var err := FileAccess.get_open_error()
		push_error("Failed to load text resource. %s"%err)
		return err
	
	res.text = file.get_as_text()

	return res

