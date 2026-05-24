extends Control
@onready var node: Node = $"../Node"

@onready var wave_label = $Waves
@onready var enemies_label = $EnemiesLeft

func _ready():
	# Find the WaveManager in the scene
	# If it's an Autoload, use 'WaveManager'. If it's a node, use the path.
	var wm = node
	
	# Connect the signals
	wm.wave_started.connect(_on_wave_started)
	wm.enemies_left_changed.connect(_on_enemies_changed)

func _on_wave_started(num: int, _total: int):
	# "Passed" waves is usually current wave minus 1
	var waves_passed = num - 1
	wave_label.text = "Waves Passed: " + str(waves_passed) + " (Current: " + str(num) + ")"

func _on_enemies_changed(count: int):
	enemies_label.text = "Planes Left: " + str(count)
