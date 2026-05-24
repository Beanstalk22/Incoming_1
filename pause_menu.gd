extends CanvasLayer

# ==========================================
# ENUMS & STATE
# ==========================================
enum ConfirmAction { NONE, RESTART, MAIN_MENU }
var pending_action: ConfirmAction = ConfirmAction.NONE

# ==========================================
# NODES
# ==========================================
@onready var menu_ui: VBoxContainer = $PauseMenu/VBoxContainer
@onready var settings_panel: Control = %Menu_pause


# We will generate these dynamically through code so you don't have to!
var confirmation_panel: Control 
var confirm_label: Label

# ==========================================
# BUILT-IN METHODS
# ==========================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Generate the confirmation UI automatically
	_create_confirmation_ui()
	
	# Initialize default game state
	get_tree().paused = false
	hide()
	
	# Setup initial UI visibility
	if menu_ui: 
		menu_ui.show()
	if settings_panel:
		settings_panel.hide()
		# Safely connect the signal
		if not settings_panel.back_pressed.is_connected(_on_settings_back_pressed):
			settings_panel.back_pressed.connect(_on_settings_back_pressed)
	if confirmation_panel:
		confirmation_panel.hide()

func _input(event: InputEvent) -> void:
	# "ui_cancel" is tied to ESC by default in the Input Map.
	if event.is_action_pressed("ui_cancel"):
		_handle_pause_input()

# ==========================================
# DYNAMIC UI GENERATOR
# ==========================================
func _create_confirmation_ui() -> void:
	# 1. Base Container
	confirmation_panel = Control.new()
	confirmation_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_panel.hide()
	
	# Add it to the PauseMenu node if it exists, otherwise add to self
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
	# Make the text slightly larger via inline scale (optional)
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
		# If settings are open, ESC goes back one menu level
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
# SIGNAL HANDLERS
# ==========================================
func _on_resume_pressed() -> void:
	resume_game()

func _on_restart_pressed() -> void:
	_show_confirmation_menu(ConfirmAction.RESTART)

func _on_settings_pressed() -> void:
	_show_settings_menu()

func _on_settings_back_pressed() -> void:
	_show_main_pause_menu()

func _on_main_menu_pressed() -> void:
	_show_confirmation_menu(ConfirmAction.MAIN_MENU)

# --- NEW CONFIRMATION SIGNAL HANDLERS ---
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
