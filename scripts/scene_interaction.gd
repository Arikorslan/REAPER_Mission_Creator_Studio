extends Control


var scene
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_STOP
func _can_drop_data(at: Vector2, value: Variant) -> bool:
	return scene != null and scene._can_drop_data(at, value)
func _drop_data(at: Vector2, value: Variant) -> void:
	if scene != null: scene._drop_data(at, value)
func _gui_input(event: InputEvent) -> void:
	if scene != null: scene._gui_input(event)
	accept_event()
