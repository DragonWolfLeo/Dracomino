extends Window

func _ready() -> void:
	close_requested.connect(queue_free)
	loadChangelog()	
	
func loadChangelog():
	var changelog:String = load("res://changelog.txt").text.replace("\r","")
	var regex := RegEx.create_from_string("(\\S| )+") # Should get first line containing version and date
	var rm := regex.search(changelog)
	find_child("ChangeLog").text = changelog

func _on_focus_exited() -> void:
	queue_free()
