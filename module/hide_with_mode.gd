extends CanvasLayer

func _ready() -> void:
    var mode:Mode = DracominoUtil.getParentMode(self)
    if mode:
        mode.visibility_changed.connect(_on_visibility_changed.bind(mode))

func _on_visibility_changed(node:CanvasItem):
    visible = node.is_visible_in_tree()