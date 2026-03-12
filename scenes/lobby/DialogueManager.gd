extends RefCounted
class_name DialogueManager

const DIALOGUE: Dictionary = {
	"first_visit": "Welcome, fragment of the Ancient. The Dire stir in the deep. Spend your shards wisely.",
	"after_win": "Victory... but the Dire will return. Stronger. Rest now, and prepare.",
	"after_loss": "Your light scattered, but not extinguished. The ore remembers. Try again.",
}


static func get_line(trigger: String) -> String:
	return DIALOGUE.get(trigger, "The campfire crackles softly.")
