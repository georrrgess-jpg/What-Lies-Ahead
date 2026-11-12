extends Node
## Explicit unlock grants (for Requirement.Kind.GRANTED) stored in the profile.

func is_granted(id: StringName) -> bool:
	return Profile.section("unlocks").get("granted", []).has(String(id))


func grant(id: StringName) -> void:
	var sec := Profile.section("unlocks")
	var list: Array = sec.get("granted", [])
	if not list.has(String(id)):
		list.append(String(id))
		sec["granted"] = list
