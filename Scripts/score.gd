extends Label

func _ready():
	# Connect to the signal we made in GameManager
	GameManager.score_changed.connect(_on_score_updated)
	# Set initial text
	text = "SCORE: 0"


func _on_score_updated(new_score):
	text = "SCORE: " + str(new_score)
	
	# Optional: Make the text "punch" or scale up when it changes
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	
