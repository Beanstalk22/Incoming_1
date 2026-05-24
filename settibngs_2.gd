extends Control

# ==========================================
# ENUMS & STATE
# ==========================================
enum ConfirmAction { NONE, RESTART, MAIN_MENU }
var pending_action: ConfirmAction = ConfirmAction.NONE

# Settings Config Path
const SAVE_PATH = "res://settings.cfg"

# Default Settings Values
var settings_data = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"vsync": true
}

# ==========================================
# NODES
# ==========================================
@onready var menu_ui: VBoxContainer = $PauseMenu/VBoxContainer

# We will dynamically generate these to keep your editor workflow worry-free!
var settings_panel: Control
var confirmation_panel: Control 
var confirm_label: Label

# Settings UI Element References
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_chk: CheckButton
var vsync_chk: CheckButton

# ==========================================
# BUILT-IN METHODS
# ==========================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. Load the user's existing preferences first
	load_settings()
	
	# 2. Generate both confirmation and settings UI automatically
	_create_settings_ui()
	_create_confirmation_ui()
	
	# Initialize default game state
	get_tree().paused = false
	hide()
	
	# Setup initial UI visibility
	if menu_ui: 
		menu_ui.show()
	if settings_panel:
		settings_panel.hide()
	if confirmation_panel:
		confirmation_panel.hide()

func _input(event: InputEvent) -> void:
	# "ui_cancel" is tied to ESC by default in the Input Map.
	if event.is_action_pressed("ui_cancel"):
		_handle_pause_input()

# ==========================================
# SETTINGS CONFIGURATION (SAVE / LOAD)
# ==========================================
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err == OK:
		settings_data.master_volume = config.get_value("audio", "master_volume", settings_data.master_volume)
		settings_data.music_volume = config.get_value("audio", "music_volume", settings_data.music_volume)
		settings_data.sfx_volume = config.get_value("audio", "sfx_volume", settings_data.sfx_volume)
		settings_data.fullscreen = config.get_value("display", "fullscreen", settings_data.fullscreen)
		settings_data.vsync = config.get_value("display", "vsync", settings_data.vsync)
	
	# Apply these settings to the actual game engine
	apply_audio_settings()
	apply_display_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", settings_data.master_volume)
	config.set_value("audio", "music_volume", settings_data.music_volume)
	config.set_value("audio", "sfx_volume", settings_data.sfx_volume)
	config.set_value("display", "fullscreen", settings_data.fullscreen)
	config.set_value("display", "vsync", settings_data.vsync)
	
	config.save(SAVE_PATH)

func apply_audio_settings() -> void:
	set_bus_volume("Master", settings_data.master_volume)
	set_bus_volume("Music", settings_data.music_volume)
	set_bus_volume("SFX", settings_data.sfx_volume)

func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		# Convert slider linear value (0.0 to 1.0) to decibels
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		# Mute if slider is all the way to the left
		AudioServer.set_bus_mute(bus_index, value <= 0.001)

func apply_display_settings() -> void:
	if settings_data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	if settings_data.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# ==========================================
# DYNAMIC UI GENERATOR
# ==========================================
func _create_settings_ui() -> void:
	# 1. Base Container
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.hide()
	
	var parent_node = get_node_or_null("PauseMenu")
	if parent_node:
		parent_node.add_child(settings_panel)
	else:
		add_child(settings_panel)
		
	# 2. Dark Overlay Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.05, 0.95) # Clean flat dark gray
	settings_panel.add_child(bg)
	
	# 3. Centered Layout Panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(center)
	
	# 4. Main Menu structure
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	main_vbox.custom_minimum_size = Vector2(400, 0)
	center.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.scale = Vector2(1.5, 1.5)
	title.pivot_offset = Vector2(title.size.x / 2, title.size.y / 2)
	main_vbox.add_child(title)
	
	# --- AUDIO SECTION ---
	var audio_section = VBoxContainer.new()
	audio_section.add_theme_constant_override("separation", 12)
	main_vbox.add_child(audio_section)
	
	var audio_label = Label.new()
	audio_label.text = "AUDIO PREFERENCES"
	audio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	audio_section.add_child(audio_label)
	
	# Master Slider Setup
	master_slider = _create_labeled_slider(audio_section, "Master Volume", settings_data.master_volume)
	master_slider.value_changed.connect(_on_master_volume_changed)
	
	# Music Slider Setup
	music_slider = _create_labeled_slider(audio_section, "Music Volume", settings_data.music_volume)
	music_slider.value_changed.connect(_on_music_volume_changed)
	
	# SFX Slider Setup
	sfx_slider = _create_labeled_slider(audio_section, "SFX Volume", settings_data.sfx_volume)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Separator line
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.2, 0.2, 0.2, 1.0)
	main_vbox.add_child(sep)
	
	# --- GRAPHICS SECTION ---
	var graphics_section = VBoxContainer.new()
	graphics_section.add_theme_constant_override("separation", 10)
	main_vbox.add_child(graphics_section)
	
	var graphics_label = Label.new()
	graphics_label.text = "VIDEO PREFERENCES"
	graphics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	graphics_section.add_child(graphics_label)
	
	# Fullscreen Checkbox
	fullscreen_chk = CheckButton.new()
	fullscreen_chk.text = "Fullscreen Mode"
	fullscreen_chk.button_pressed = settings_data.fullscreen
	fullscreen_chk.toggled.connect(_on_fullscreen_toggled)
	graphics_section.add_child(fullscreen_chk)
	
	# VSync Checkbox
	vsync_chk = CheckButton.new()
	vsync_chk.text = "Enable VSync"
	vsync_chk.button_pressed = settings_data.vsync
	vsync_chk.toggled.connect(_on_vsync_toggled)
	graphics_section.add_child(vsync_chk)
	
	# --- NAVIGATION BACK BUTTON ---
	var back_btn = Button.new()
	back_btn.text = "Back & Save"
	back_btn.custom_minimum_size = Vector2(0, 45)
	back_btn.pressed.connect(_on_settings_back_pressed)
	main_vbox.add_child(back_btn)

func _create_labeled_slider(parent: Node, label_text: String, start_val: float) -> HSlider:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 15)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(130, 0)
	container.add_child(lbl)
	
	var sld = HSlider.new()
	sld.min_value = 0.0
	sld.max_value = 1.0
	sld.step = 0.01
	sld.value = start_val
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(sld)
	
	parent.add_child(container)
	return sld

func _create_confirmation_ui() -> void:
	# 1. Base Container
	confirmation_panel = Control.new()
	confirmation_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_panel.hide()
	
	var parent_node = get_node_or_null("PauseMenu")
	if parent_node:
		parent_node.add_child(confirmation_panel)
	else:
		add_child(confirmation_panel)
		
	# 2. Dark Overlay Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9) # Dark transparent background
	confirmation_panel.add_child(bg)
	
	# 3. Center Container to keep everything perfectly in the middle
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_panel.add_child(center)
	
	# 4. Vertical layout for Label and Buttons
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 25) # Space between text and buttons
	center.add_child(vbox)
	
	# 5. The Question Text
	confirm_label = Label.new()
	confirm_label.text = "Are you sure?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.scale = Vector2(1.2, 1.2) 
	confirm_label.pivot_offset = Vector2(confirm_label.size.x / 2, confirm_label.size.y / 2)
	vbox.add_child(confirm_label)
	
	# 6. Horizontal layout for Yes/No buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40) # Space between buttons
	vbox.add_child(hbox)
	
	# 7. Yes Button
	var yes_btn = Button.new()
	yes_btn.text = "   Yes   "
	yes_btn.custom_minimum_size = Vector2(120, 45)
	yes_btn.pressed.connect(_on_confirm_yes_pressed)
	hbox.add_child(yes_btn)
	
	# 8. No Button
	var no_btn = Button.new()
	no_btn.text = "   No   "
	no_btn.custom_minimum_size = Vector2(120, 45)
	no_btn.pressed.connect(_on_confirm_no_pressed)
	hbox.add_child(no_btn)

# ==========================================
# CORE STATE LOGIC
# ==========================================
func _handle_pause_input() -> void:
	if get_tree().paused:
		# If settings are open, ESC goes back to main pause menu and saves changes
		if settings_panel and settings_panel.visible:
			_show_main_pause_menu()
		# If confirmation is open, ESC goes back to main pause menu
		elif confirmation_panel and confirmation_panel.visible:
			_show_main_pause_menu()
		else:
			resume_game()
	else:
		pause_game()

func pause_game() -> void:
	get_tree().paused = true
	show()
	
	_show_main_pause_menu()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game() -> void:
	get_tree().paused = false
	hide()
	
	if settings_panel: settings_panel.hide()
	if confirmation_panel: confirmation_panel.hide()
	pending_action = ConfirmAction.NONE
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ==========================================
# UI HELPER METHODS
# ==========================================
func _show_main_pause_menu() -> void:
	if menu_ui: menu_ui.show()
	if settings_panel: settings_panel.hide()
	if confirmation_panel: confirmation_panel.hide()
	pending_action = ConfirmAction.NONE

func _show_settings_menu() -> void:
	if menu_ui: menu_ui.hide()
	if confirmation_panel: confirmation_panel.hide()
	if settings_panel: settings_panel.show()
	
	# Keep the interface current with actual loaded settings
	if master_slider: master_slider.value = settings_data.master_volume
	if music_slider: music_slider.value = settings_data.music_volume
	if sfx_slider: sfx_slider.value = settings_data.sfx_volume
	if fullscreen_chk: fullscreen_chk.button_pressed = settings_data.fullscreen
	if vsync_chk: vsync_chk.button_pressed = settings_data.vsync

func _show_confirmation_menu(action: ConfirmAction) -> void:
	pending_action = action
	
	# Update the text dynamically based on what the user is trying to do
	if confirm_label:
		if action == ConfirmAction.RESTART:
			confirm_label.text = "Are you sure you want to restart?"
		elif action == ConfirmAction.MAIN_MENU:
			confirm_label.text = "Are you sure you want to leave?\nUnsaved progress will be lost."

	if menu_ui: menu_ui.hide()
	if settings_panel: settings_panel.hide()
	if confirmation_panel: confirmation_panel.show()

# ==========================================
# SIGNAL HANDLERS & CALLBACKS
# ==========================================
func _on_resume_pressed() -> void:
	resume_game()

func _on_restart_pressed() -> void:
	_show_confirmation_menu(ConfirmAction.RESTART)

func _on_settings_pressed() -> void:
	_show_settings_menu()

func _on_settings_back_pressed() -> void:
	# Save preferences to device when user exits settings screen
	save_settings()
	_show_main_pause_menu()

func _on_main_menu_pressed() -> void:
	_show_confirmation_menu(ConfirmAction.MAIN_MENU)

# --- SETTINGS INPUT CALLBACKS ---

func _on_master_volume_changed(value: float) -> void:
	settings_data.master_volume = value
	set_bus_volume("Master", value)

func _on_music_volume_changed(value: float) -> void:
	settings_data.music_volume = value
	set_bus_volume("Music", value)

func _on_sfx_volume_changed(value: float) -> void:
	settings_data.sfx_volume = value
	set_bus_volume("SFX", value)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	settings_data.fullscreen = toggled_on
	apply_display_settings()

func _on_vsync_toggled(toggled_on: bool) -> void:
	settings_data.vsync = toggled_on
	apply_display_settings()

# --- CONFIRMATION SIGNAL HANDLERS ---

func _on_confirm_yes_pressed() -> void:
	match pending_action:
		ConfirmAction.RESTART:
			resume_game()
			get_tree().reload_current_scene()
		ConfirmAction.MAIN_MENU:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://m_menu.tscn")
	
	pending_action = ConfirmAction.NONE

func _on_confirm_no_pressed() -> void:
	_show_main_pause_menu()
