extends Control

# ==========================================
# ENUMS & STATE
# ==========================================
enum ConfirmAction { NONE, RESTART, MAIN_MENU }
var pending_action: ConfirmAction = ConfirmAction.NONE

# ==========================================
# NODES
# ==========================================
@onready var menu_ui: VBoxContainer = $PauseMenu/VBoxContainer
@onready var settings_panel: Control = $PauseMenu/Menu_pause

# Generated dynamically with optimized WWI Military Stencils
var confirmation_panel: Control 
var confirm_label: Label

# ==========================================
# BUILT-IN METHODS
# ==========================================
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Generate the stylized military confirmation overlay programmatically
	_create_confirmation_ui()
	
	# Default game state
	get_tree().paused = false
	hide()
	
	# Initial visibility configurations
	if menu_ui: 
		menu_ui.show()
	if settings_panel:
		settings_panel.hide()
		# Connect the custom signal safely
		if not settings_panel.back_pressed.is_connected(_on_settings_back_pressed):
			settings_panel.back_pressed.connect(_on_settings_back_pressed)
	if confirmation_panel:
		confirmation_panel.hide()

func _input(event: InputEvent) -> void:
	# Esc is bound to ui_cancel by default
	if event.is_action_pressed("ui_cancel"):
		_handle_pause_input()

# ==========================================
# DYNAMIC MILITARY THEME UI GENERATOR
# ==========================================
func _create_confirmation_ui() -> void:
	# 1. Base Container
	confirmation_panel = Control.new()
	confirmation_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_panel.hide()
	
	# Attach to hierarchy
	var parent_node = get_node_or_null("PauseMenu")
	if parent_node:
		parent_node.add_child(confirmation_panel)
	else:
		add_child(confirmation_panel)
		
	# 2. Dark Iron Overlay Plate (Aesthetic Background)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.15, 0.14, 0.95) # Dark trench charcoal iron
	confirmation_panel.add_child(bg)
	
	# 3. Center Alignment Container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_panel.add_child(center)
	
	# 4. Vertical layout structure for military orders
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 25)
	center.add_child(vbox)
	
	# 5. Stenciled Order Header Text
	confirm_label = Label.new()
	confirm_label.text = "ARE YOU READY TO DISOBEY COMMAND?"
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Styling using raw styling overrides to simulate weathered soldier's paybook parchment look
	confirm_label.add_theme_color_override("font_color", Color("#C5BAA1")) # Vintage parchment color
	confirm_label.scale = Vector2(1.1, 1.1) 
	confirm_label.pivot_offset = Vector2(confirm_label.size.x / 2.0, confirm_label.size.y / 2.0)
	vbox.add_child(confirm_label)
	
	# 6. Horizontal layout for brass selection toggles
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)
	
	# Styleboxes for buttons (Trench green buttons with Brass highlight borders)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#3E4A3A") # Wool Olive
	btn_normal.border_color = Color("#C99B41") # Tarnished Brass
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 0 # No round edges!
	btn_normal.corner_radius_top_right = 0
	btn_normal.corner_radius_bottom_left = 0
	btn_normal.corner_radius_bottom_right = 0
	
	var btn_hover = btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#556B52") # Light Green active highlighting
	
	# 7. Affirmative/Yes Button
	var yes_btn = Button.new()
	yes_btn.text = " AFFIRM "
	yes_btn.custom_minimum_size = Vector2(140, 45)
	yes_btn.add_theme_stylebox_override("normal", btn_normal)
	yes_btn.add_theme_stylebox_override("hover", btn_hover)
	yes_btn.add_theme_color_override("font_color", Color("#C5BAA1"))
	yes_btn.pressed.connect(_on_confirm_yes_pressed)
	hbox.add_child(yes_btn)
	
	# 8. Negative/No Button
	var no_btn = Button.new()
	no_btn.text = " DISMISS "
	no_btn.custom_minimum_size = Vector2(140, 45)
	no_btn.add_theme_stylebox_override("normal", btn_normal)
	no_btn.add_theme_stylebox_override("hover", btn_hover)
	no_btn.add_theme_color_override("font_color", Color("#C5BAA1"))
	no_btn.pressed.connect(_on_confirm_no_pressed)
	hbox.add_child(no_btn)

# ==========================================
# CORE STATE LOGIC
# ==========================================
func _handle_pause_input() -> void:
	if get_tree().paused:
		# Escape exits settings menu first
		if settings_panel and settings_panel.visible:
			_show_main_pause_menu()
		# Escape exits confirmation layout back to main index
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
	
	if settings_panel: 
		settings_panel.hide()
	if confirmation_panel: 
		confirmation_panel.hide()
	pending_action = ConfirmAction.NONE
		
	# Re-capture the mouse cursor so our player camera works seamlessly
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ==========================================
# UI NAVIGATION ROUTINES
# ==========================================
func _show_main_pause_menu() -> void:
	if menu_ui: 
		menu_ui.show()
	if settings_panel: 
		settings_panel.hide()
	if confirmation_panel: 
		confirmation_panel.hide()
	pending_action = ConfirmAction.NONE

func _show_settings_menu() -> void:
	if menu_ui: 
		menu_ui.hide()
	if confirmation_panel: 
		confirmation_panel.hide()
	if settings_panel: 
		settings_panel.show()

func _show_confirmation_menu(action: ConfirmAction) -> void:
	pending_action = action
	
	# Thematic military descriptions
	if confirm_label:
		if action == ConfirmAction.RESTART:
			confirm_label.text = "CONFIRM ORDERS: SECURE BATTERY & REBOOT MISSION?"
		elif action == ConfirmAction.MAIN_MENU:
			confirm_label.text = "DESERT DEFENSE POST?\nALL UNSAVED CAMPAIGN GAINS WILL BE LOST."

	if menu_ui: 
		menu_ui.hide()
	if settings_panel: 
		settings_panel.hide()
	if confirmation_panel: 
		confirmation_panel.show()

# ==========================================
# BUTTON SIGNAL HANDLERS
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

# ==========================================
# CONFIRMATION ACTION ROUTINES
# ==========================================
func _on_confirm_yes_pressed() -> void:
	match pending_action:
		ConfirmAction.RESTART:
			resume_game()
			get_tree().reload_current_scene()
		ConfirmAction.MAIN_MENU:
			# Unpause the engine background before loading a new active scene
			get_tree().paused = false
			get_tree().change_scene_to_file("res://m_menu.tscn")
	
	pending_action = ConfirmAction.NONE

func _on_confirm_no_pressed() -> void:
	_show_main_pause_menu()
