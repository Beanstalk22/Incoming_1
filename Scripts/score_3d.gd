# PointsPopup.gd
extends Label3D

func _ready():
	text = "+100 TARGET DESTROYED"
	var tween = create_tween()
	# Float Up
	tween.tween_property(self, "position", position + Vector3(0, 2, 0), 1.0)
	# Fade Out
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	# Delete when done
	tween.finished.connect(queue_free)
