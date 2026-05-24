extends Control


# Type-hinted references for better autocompletion and memory safety
var name_input: LineEdit
var music_slider: HSlider
var sfx_slider: HSlider
var sensitivity_slider: HSlider
var zoom_slider: HSlider
var master_slider: HSlider

@onready var tabs: Dictionary = {
	"general": _resolve_node(["Panel/PanelContainer3/General"]),
	"sound": _resolve_node(["Panel/PanelContainer3/Sound"]),
	"controls": _resolve_node(["Panel/PanelContainer3/Controls"])
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Resolve nodes and cast immediately to expected types
	name_input = _resolve_node([
		"Panel/PanelContainer3/General/NameSetter/name_input", 
		"Panel/PanelContainer3/General/NameSetter/LineEdit"
	]) as LineEdit
	
	master_slider = _get_slider_from_node(_resolve_node(["Panel/PanelContainer3/Sound/VBoxContainer/master"]))
	music_slider = _get_slider_from_node(_resolve_node(["Panel/PanelContainer3/Sound/VBoxContainer/music"]))
	sfx_slider = _get_slider_from_node(_resolve_node(["Panel/PanelContainer3/Sound/VBoxContainer/sfx"]))
	sensitivity_slider = _get_slider_from_node(_resolve_node(["Panel/PanelContainer3/Controls/VBoxContainer/sensitivity"]))
	zoom_slider = _get_slider_from_node(_resolve_node(["Panel/PanelContainer3/Controls/VBoxContainer/zoom_sens"]))
	
	_switch_tab("general")
	
	if GameManager.player_profile == null:
		await GameManager.data_loaded
		
	_setup_ui_from_profile()
	_connect_ui_signals()

# ==========================================
# DATA ACCESS (Flat Resource Properties)
# ==========================================

func _get_setting(property_name: String, default_val: Variant) -> Variant:
	if not GameManager.player_profile:
		return default_val
	# Safely access the property on the PlayerData resource
	if property_name in GameManager.player_profile:
		return GameManager.player_profile.get(property_name)
	return default_val

func _set_setting(property_name: String, value: Variant) -> void:
	if not GameManager.player_profile:
		return
	# Safely set the property if it exists in your PlayerData definition
	if property_name in GameManager.player_profile:
		GameManager.player_profile.set(property_name, value)
	else:
		printerr("[SETTINGS] Property '", property_name, "' not found in PlayerData definition!")

# ==========================================
# UI INITIALIZATION & BINDING
# ==========================================

func _setup_ui_from_profile() -> void:
	if name_input:
		name_input.text = str(_get_setting("player_name", "Gunner Recruit"))
		
	_configure_slider(master_slider, _get_setting("master_volume", 1), 0.0, 1.0, 0.1)
	_configure_slider(music_slider, _get_setting("music_volume", 0.7), 0.0, 1.0, 0.1)
	_configure_slider(sfx_slider, _get_setting("sfx_volume", 0.8), 0.0, 1.0, 0.1)
	_configure_slider(sensitivity_slider, _get_setting("mouse_sensitivity", 0.002), 0.0005, 0.01, 0.0001)
	_configure_slider(zoom_slider, _get_setting("zoom_sensitivity", 0.001), 0.0001, 0.005, 0.0001)

func _configure_slider(slider: HSlider, val: float, min_v: float, max_v: float, step_v: float) -> void:
	if not slider: return
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = val

func _connect_ui_signals() -> void:
	if name_input and not name_input.text_changed.is_connected(_on_name_input_text_changed):
		name_input.text_changed.connect(_on_name_input_text_changed)
		
	_safe_connect(master_slider, _on_master_volume_changed)
	_safe_connect(music_slider, _on_music_volume_changed)
	_safe_connect(sfx_slider, _on_sfx_volume_changed)
	_safe_connect(sensitivity_slider, _on_mouse_sensitivity_changed)
	_safe_connect(zoom_slider, _on_zoom_sensitivity_changed)

func _safe_connect(slider: HSlider, callable: Callable) -> void:
	if slider and not slider.value_changed.is_connected(callable):
		slider.value_changed.connect(callable)

# ==========================================
# SIGNAL CALLBACKS
# ==========================================

func _on_name_input_text_changed(new_text: String) -> void:
	_set_setting("player_name", new_text.strip_edges())

func _on_master_volume_changed(value: float) -> void:
	_set_setting("master_volume", value)
	GameManager.apply_audio_settings()
	
func _on_music_volume_changed(value: float) -> void:
	_set_setting("music_volume", value)
	GameManager.apply_audio_settings()

func _on_sfx_volume_changed(value: float) -> void:
	_set_setting("sfx_volume", value)
	GameManager.apply_audio_settings()

func _on_mouse_sensitivity_changed(value: float) -> void:
	_set_setting("mouse_sensitivity", value)
	GameManager.apply_control_settings()

func _on_zoom_sensitivity_changed(value: float) -> void:
	_set_setting("zoom_sensitivity", value)
	GameManager.apply_control_settings()

# ==========================================
# NAVIGATION & DIALOGS
# ==========================================

func _switch_tab(target_tab: String) -> void:
	for tab_name in tabs:
		if tabs[tab_name]:
			tabs[tab_name].visible = (tab_name == target_tab)

func _on_general_pressed() -> void: _switch_tab("general")
func _on_sound_pressed() -> void: _switch_tab("sound")
func _on_controls_pressed() -> void: _switch_tab("controls")

func _on_back_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Save Changes"
	dialog.dialog_text = "Do you want to save your current settings changes?"
	dialog.ok_button_text = "Save"
	dialog.get_cancel_button().text = "Cancel"
	dialog.add_button("Discard", true, "discard")
	
	add_child(dialog)
	
	dialog.confirmed.connect(func():
		if GameManager.player_profile: GameManager.save_player_profile()
		_close_dialog(dialog)
	)
	
	dialog.custom_action.connect(func(action: StringName):
		if action == &"discard":
			if GameManager.player_profile: GameManager.load_player_profile()
			_close_dialog(dialog)
	)
	
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _close_dialog(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	get_tree().change_scene_to_file("res://m_menu.tscn")

# ==========================================
# UTILITIES
# ==========================================

func _resolve_node(paths: Array[String]) -> Node:
	for path in paths:
		if has_node(path): return get_node(path)
	printerr("[SETTINGS] WARNING: Could not resolve node for: ", paths[0])
	return null

func _get_slider_from_node(node: Node) -> HSlider:
	if not node: return null
	if node is HSlider: return node
	
	for child in node.get_children():
		if child is HSlider: return child
	return null
