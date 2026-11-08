extends RefCounted

const STATE_PATH := "user://creator_library.json"
const RECENT_MAX := 8
var recents: Array = []
var state_path := STATE_PATH

func load_state() -> void:
	recents = []
	if not FileAccess.file_exists(state_path): return
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null: return
	var text := file.get_as_text(); file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for id in parsed.get("recents", []):
			if id is String and not recents.has(id): recents.append(id)

func save_state() -> void:
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({ "recents": recents}))
	file.close()

func note_used(id: String) -> void:
	if id.is_empty(): return
	recents.erase(id)
	recents.push_front(id)
	while recents.size() > RECENT_MAX: recents.pop_back()

static func category_for(id: String, name: String) -> String:
	var text := (id + " " + name).to_lower()
	if text.contains("texture") or text.contains("grass") or text.contains("sand") or text.contains("rock") and not text.contains("hill"): pass
	for key in ["tex", "texture", "grass", "sand", "gravel", "snow", "mud", "asphalt"]:
		if text.contains(key): return "Textures"
	for key in ["house", "building", "wall", "brick", "tower", "bunker", "shed", "village"]:
		if text.contains(key): return "Buildings"
	for key in ["technical", "humvee", "truck", "car", "vehicle", "tank", "convoy"]:
		if text.contains(key): return "Vehicles"
	for key in ["civilian", "soldier", "person", "actor", "man", "woman", "patrol"]:
		if text.contains(key): return "People"
	for key in ["terrain", "hill", "mountain", "plateau", "ridge", "rock", "tree", "bush"]:
		if text.contains(key): return "Nature"
	for key in ["tb2", "drone", "aircraft", "uav", "start", "spawn"]:
		if text.contains(key): return "Aircraft"
	return "Other"

func index(library, custom: Dictionary) -> Array:
	var out: Array = []
	for row: Dictionary in library.entries(custom):
		var id := str(row.get("id", ""))
		out.append({ "id": id, "name": str(row.get("name", id)), "kind": str(row.get("kind", "")),
			"category": category_for(id, str(row.get("name", id))), "recent": recents.has(id)})
	return out

func categories() -> Array: return ["All", "Buildings", "Vehicles", "People", "Nature", "Aircraft", "Textures", "Other"]

func filter(entries: Array, query: String, category := "All") -> Array:
	var needle := query.strip_edges().to_lower()
	var out: Array = []
	for row: Dictionary in entries:
		if category != "All" and str(row.get("category", "Other")) != category: continue
		if needle.is_empty():
			out.append(row); continue
		var hay := (str(row.get("id", "")) +" " + str(row.get("name", "")) +" " + str(row.get("category", "")) +" " + str(row.get("kind", ""))).to_lower()
		if hay.contains(needle): out.append(row)
	return out

func recents_first(entries: Array) -> Array:
	var recent: Array = []
	var rest: Array = []
	for row: Dictionary in entries:
		if recents.has(str(row.get("id", ""))): recent.append(row)
		else: rest.append(row)
	recent.sort_custom(func (a, b): return recents.find(str(a.id)) < recents.find(str(b.id)))
	return recent + rest

func placed_counts(objects: Array) -> Dictionary:
	var counts: Dictionary = {}
	for row: Dictionary in objects:
		var asset := str(row.get("asset", ""))
		counts[asset] = int(counts.get(asset, 0)) +1
	return counts
