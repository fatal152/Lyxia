extends Node

var score = 0
@onready var label: Label = $Label

func add_points():
	score += 1
	label.text = "YOU'VE MADE IT you collected " + str(score) + " coins"
