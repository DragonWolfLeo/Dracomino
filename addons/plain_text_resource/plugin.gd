@tool
extends EditorPlugin

var dialogueEditorHighlighter:DialogueEditorSyntaxHighlighter

func _get_plugin_name() -> String:
	return "Plain Text Resource"

func _enter_tree():
	if Engine.is_editor_hint():
		dialogueEditorHighlighter = DialogueEditorSyntaxHighlighter.new()
		dialogueEditorHighlighter.matchEditorSettings()
		var scriptEditor = EditorInterface.get_script_editor()
		scriptEditor.register_syntax_highlighter(dialogueEditorHighlighter)

func _exit_tree():
	if is_instance_valid(dialogueEditorHighlighter):
		var scriptEditor = EditorInterface.get_script_editor()
		scriptEditor.unregister_syntax_highlighter(dialogueEditorHighlighter)
		dialogueEditorHighlighter = null
