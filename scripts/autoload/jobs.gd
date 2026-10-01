extends Node
## Delivery jobs: the job board picks from assets/jobs/jobs.json, the player
## accepts up to GameState.cargo_slots, then talking to the pickup / dropoff
## npc (Interactable.npc_id) hands the item over. State lives in GameState
## (active_jobs / done_jobs / failed_jobs) so it is saved with everything else.

signal jobs_changed
## Emitted after a dropoff with the reward actually paid.
signal job_delivered(id: String, reward: int, late: bool)

const JOBS_PATH := "res://assets/jobs/jobs.json"

var _jobs: Dictionary = {}  # id -> job dict
var _order: Array[String] = []


func _ready() -> void:
	load_file(JOBS_PATH)


func load_file(path: String) -> void:
	_jobs.clear()
	_order.clear()
	if not FileAccess.file_exists(path):
		push_error("Jobs: missing %s" % path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array:
		push_error("Jobs: %s is not a JSON array" % path)
		return
	for job in parsed:
		if job is Dictionary and job.has("id"):
			_jobs[job["id"]] = job
			_order.append(job["id"])


func get_job(id: String) -> Dictionary:
	return _jobs.get(id, {})


func all_ids() -> Array[String]:
	return _order.duplicate()


## Jobs the board can offer right now.
func available() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _order:
		if is_active(id) or GameState.done_jobs.has(id):
			continue
		var ok := true
		for flag in _jobs[id].get("requires", []):
			if not GameState.has_flag(str(flag)):
				ok = false
		if ok:
			out.append(_jobs[id])
	return out


func is_active(id: String) -> bool:
	return _active_entry(id) != null


func _active_entry(id: String):
	for entry in GameState.active_jobs:
		if entry.get("id") == id:
			return entry
	return null


func active_jobs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in GameState.active_jobs:
		var job := get_job(str(entry["id"]))
		if not job.is_empty():
			var merged := job.duplicate()
			merged["picked"] = entry.get("picked", false)
			merged["due_tick"] = entry.get("due_tick", 0)
			out.append(merged)
	return out


func cargo_free() -> int:
	return GameState.cargo_slots - GameState.active_jobs.size()


func accept(id: String) -> bool:
	if not _jobs.has(id) or is_active(id) or GameState.done_jobs.has(id) or cargo_free() <= 0:
		return false
	var job: Dictionary = _jobs[id]
	var due := GameState.tick + int(job.get("deadline_slots", 6)) * GameState.TICKS_PER_SLOT
	GameState.active_jobs.append({"id": id, "picked": false, "due_tick": due})
	GameState.notice.emit("รับงาน: %s" % job["title"])
	jobs_changed.emit()
	return true


func abandon(id: String) -> void:
	var entry = _active_entry(id)
	if entry == null:
		return
	GameState.active_jobs.erase(entry)
	var job := get_job(id)
	if entry.get("picked", false):
		GameState.take_item(str(job.get("item", "")))
	GameState.failed_jobs.append(id)
	GameState.notice.emit("ทิ้งงาน: %s" % job.get("title", id))
	jobs_changed.emit()


func is_late(entry: Dictionary) -> bool:
	return GameState.tick > int(entry.get("due_tick", 0))


## Called by Interactable before its own dialog. Returns true when a job used
## the interaction (pickup or dropoff happened).
func on_interact(npc_id: String) -> bool:
	if npc_id.is_empty():
		return false
	# dropoffs first: a picked job waiting for this npc
	for entry in GameState.active_jobs:
		var job := get_job(str(entry["id"]))
		if entry.get("picked", false) and job.get("dropoff", {}).get("npc", "") == npc_id:
			_deliver(entry, job)
			return true
	for entry in GameState.active_jobs:
		var job := get_job(str(entry["id"]))
		if not entry.get("picked", false) and job.get("pickup", {}).get("npc", "") == npc_id:
			entry["picked"] = true
			GameState.give_item(str(job.get("item", "")))
			Dialog.start_lines(job.get("pickup_lines", []), "job_pickup_" + str(job["id"]))
			jobs_changed.emit()
			return true
	return false


func _deliver(entry: Dictionary, job: Dictionary) -> void:
	var late := is_late(entry)
	var reward := (
		int(job.get("late_reward", job.get("reward", 0))) if late else int(job.get("reward", 0))
	)
	GameState.active_jobs.erase(entry)
	GameState.done_jobs.append(str(job["id"]))
	GameState.take_item(str(job.get("item", "")))
	GameState.add_money(reward)
	for flag in job.get("sets", []):
		GameState.set_flag(str(flag))
	GameState.advance_time(GameState.DELIVERY_TICKS)
	var lines: Array = job.get("late_lines", []) if late else job.get("dropoff_lines", [])
	if late and lines.is_empty():
		lines = job.get("dropoff_lines", [])
	Dialog.start_lines(lines, "job_dropoff_" + str(job["id"]))
	job_delivered.emit(str(job["id"]), reward, late)
	jobs_changed.emit()


## End of day: undelivered jobs fail, items are lost, a new day starts.
func sleep() -> void:
	var failed: Array[String] = []
	for entry in GameState.active_jobs.duplicate():
		failed.append(str(get_job(str(entry["id"])).get("title", entry["id"])))
		abandon(str(entry["id"]))
	GameState.new_day()
	if not failed.is_empty():
		GameState.notice.emit("งานที่ไม่ได้ส่ง: " + ", ".join(failed))
	jobs_changed.emit()
