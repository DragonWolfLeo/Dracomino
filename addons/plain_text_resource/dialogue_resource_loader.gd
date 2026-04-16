@tool
extends ResourceFormatLoader

class_name DialogueResourceLoader

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["script"])

func _get_resource_type(path: String) -> String:
	var ext = path.get_extension().to_lower()
	if ext == "script":
		return "DialogueScript"
	
	return ""

func _handles_type(typename: StringName) -> bool:
	return ClassDB.is_parent_class(typename, "Resource") or typename == "DialogueScript"

func _load(path: String, original_path: String, _use_sub_threads: bool, _cache_mode: int):
	var res := DialogueScript.new()
	
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		var err = FileAccess.get_open_error()
		push_error("For some reason, loading custom resource failed with error code: %s"%err)
		return err
	
	res.text = file.get_as_text(true)
	
	return res

