@tool
extends ScriptLanguageExtension
class_name DialogueLanguage

const SYMBOLS = {
	STATE = {
		description = \
"""**[State <id>]**
"Indicates the start of a state. The state ends when [State] is used again, or if the end of the script is reached. \
"The state tag has an optional parameter, which is the id. It is useful if you want to use [GotoState] to reach this \
"specific state, but not necessary if you want to use [NextState]. Immediately after [State], the following text \
"displayed as dialogue until reaching a tag, and will then read through [Choice] and [Jump] tags. The dialogue engine \
"finalizes current choices once a [Response] or navigation tag is reached.""",
	},
	CHOICE = {
		description = \
"""**[Choice <id> hidden?]**
Choices are the player's options for participating in the dialogue. The text after [Choice] is what is displayed. \
Once chosen, a choice will activate its response of its id. The second parameter is the "hidden" option. \
If hidden, the choice will not be displayed until [RevealChoice] shows it.""",
	},
	JUMP = {
		description = \
"""/**[Jump <id>]**
Jumps are not displayed, but immediately activates their id's response once the dialogue engine reaches a [Response].""",
	},
	RESPONSE = {
		description = \
"""/**[Response <id>]**
Responses are read once a choice or jump activates them. The following text is displayed as dialogue, and will stop \
reading once reaching another [Response] or navigation tag. [Choice] and [Jump] tags can also be in a response, and \
will be added to the current state's choices and conditions once read.""",
	},
	REVEALCHOICE = {
		description = \
"""**[RevealChoice <id>]**
This will reveal a hidden choice of the same id."""
	},
	REMAPCHOICE = {
		description = \
"""**[RemapChoice <id> <target>]**
Change a choice's response to another."""
	},
	NEXTSTATE = {
		description = \
"""***[NextState <id>]**
Advances forward into the script to the next [State] if no id is given, or to the next [State] with the matching id \
if id is given. The difference from [GotoState] is that this moves forward, while [GotoState] searches from the \
beginning of the script."""
	},
	GOTOSTATE = {
		description = \
"""**[GotoState <target>]**
Jumps to a state with the name of the target.""",
	},
	END = {
		description = \
"""
**[End]**
Ends the dialogue.""",
	},
}

func _add_global_constant(name: StringName, value: Variant) -> void:
	pass
func _add_named_global_constant(name: StringName, value: Variant) -> void:
	pass
func _auto_indent_code(code: String, from_line: int, to_line: int) -> String:
	return code
func _can_inherit_from_file() -> bool:
	return false
func _can_make_function() -> bool:
	return false
func _complete_code(code: String, path: String, owner: Object) -> Dictionary:
	return {}
# func _create_script() -> Object:
# 	return DialogueScript.new()
func _debug_get_current_stack_info() -> Array[Dictionary]:
	return []
# func _debug_get_error() -> String:
# 	return ""
# func _debug_get_globals(max_subitems: int, max_depth: int) -> Dictionary:
# 	return {}
# func _debug_get_stack_level_count() -> int:
# 	return 0
# func _debug_get_stack_level_function(level: int) -> String:
# 	return ""
# func _debug_get_stack_level_line(level: int) -> int:
# 	return 0
# func _debug_get_stack_level_locals(level: int, max_subitems: int, max_depth: int) -> Dictionary:
# 	return {}
# func _debug_get_stack_level_members(level: int, max_subitems: int, max_depth: int) -> Dictionary:
# 	return {}
# func _debug_get_stack_level_source(level: int) -> String:
# 	return ""
# func _debug_parse_stack_level_expression(level: int, expression: String, max_subitems: int, max_depth: int) -> String:
# 	return ""
# func _find_function(function: String, code: String) -> int:
# 	return 0
func _finish() -> void:
	pass
func _frame() -> void:
	pass
func _get_built_in_templates(object: StringName) -> Array[Dictionary]:
	return []
func _get_comment_delimiters() -> PackedStringArray:
	return ["//", "/* */"]
func _get_doc_comment_delimiters() -> PackedStringArray:
	return []
func _get_extension() -> String:
	return "script"
func _get_global_class_name(path: String) -> Dictionary:
	return {}
func _get_name() -> String:
	return "DialogueScript"
func _get_public_annotations() -> Array[Dictionary]:
	return []
func _get_public_constants() -> Dictionary:
	return {}
func _get_public_functions() -> Array[Dictionary]:
	return []
func _get_recognized_extensions() -> PackedStringArray:
	return ["script"]
func _get_reserved_words() -> PackedStringArray:
	return []
func _get_string_delimiters() -> PackedStringArray:
	return []
func _get_type() -> String:
	return "Dialogue"
func _handles_global_class_type(type: String) -> bool:
	return false
func _has_named_classes() -> bool:
	return false
func _init() -> void:
	pass
func _is_control_flow_keyword(keyword: String) -> bool:
	return false
func _is_using_templates() -> bool:
	return false
func _lookup_code(code: String, symbol: String, path: String, owner: Object) -> Dictionary:
	# var symbolInfo = SYMBOLS.get(symbol.to_upper(), {})
	var ret = {
		"result": OK,
		"type": symbol,
		# "class_name": "",
		# "class_member": "",
		# "description": symbolInfo.get("description", ""),

		# "is_deprecated": false,
		# "deprecated_message": "",
		# "experimental_message": "",

		# "doc_type": "",
		# "enumeration": "",
		# "is_bitfield": false,

		# "value": "",

		# "script": Script.new(),
		"script_path": path,
		# "location": -1,

	}
	return ret
# func _make_function(class_name: String, function_name: String, function_args: PackedStringArray) -> String:
# 	return ""
# func _make_template(template: String, _class_name: String, base_class_name: String) -> Script:
# 	return DialogueScript.new() as Script
func _open_in_external_editor(script: Script, line: int, column: int) -> Error:
	return OK
func _overrides_external_editor() -> bool:
	return false
func _preferred_file_name_casing() -> ScriptNameCasing:
	return SCRIPT_NAME_CASING_AUTO
# func _profiling_get_accumulated_data(info_array: int, info_max: int) -> int:
# 	return 0
# func _profiling_get_frame_data(info_array: int, info_max: int) -> int:
# 	return 0
func _profiling_set_save_native_calls(enable: bool) -> void:
	pass
func _profiling_start() -> void:
	pass
func _profiling_stop() -> void:
	pass
func _reload_all_scripts() -> void:
	pass
func _reload_scripts(scripts: Array, soft_reload: bool) -> void:
	pass
func _reload_tool_script(script: Script, soft_reload: bool) -> void:
	pass
func _remove_named_global_constant(name: StringName) -> void:
	pass
func _supports_builtin_mode() -> bool:
	return true
func _supports_documentation() -> bool:
	return false
func _thread_enter() -> void:
	pass
func _thread_exit() -> void:
	pass
func _validate(script: String, path: String, validate_functions: bool, validate_errors: bool, validate_warnings: bool, validate_safe_lines: bool) -> Dictionary:
	return {}
# func _validate_path(path: String) -> String:
# 	return ""
