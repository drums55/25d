class_name SaveSlots
extends VBoxContainer
## Save / load slot list, used by the main menu and the phone's menu tab.
## Slot 0 is the autosave (load only).

signal loaded(slot: int)
signal saved(slot: int)

var mode := "load"


func _init(m := "load") -> void:
	mode = m
	add_theme_constant_override("separation", 10)


func _ready() -> void:
	refresh()


func refresh() -> void:
	UiKit.clear(self)
	add_child(UiKit.label("บันทึกเกม" if mode == "save" else "โหลดเกม", 34, UiKit.ACCENT))
	var saves := GameState.list_saves()
	var first := 1 if mode == "save" else 0
	for slot in range(first, GameState.SAVE_SLOTS + 1):
		var meta: Dictionary = saves.get(slot, {})
		var name := "ออโต้เซฟ" if slot == 0 else "ช่อง %d" % slot
		var info := "ว่าง"
		if not meta.is_empty():
			info = (
				"วันที่ %d %s · ฿%d · หนี้ %d · %s"
				% [
					int(meta.get("day", 1)),
					meta.get("clock", ""),
					int(meta.get("money", 0)),
					int(meta.get("debt", 0)),
					meta.get("place", "")
				]
			)
		var text := "%s — %s" % [name, info]
		var b := UiKit.button(text, _on_slot.bind(slot), 26, 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = mode == "load" and meta.is_empty()
		add_child(b)


func _on_slot(slot: int) -> void:
	if mode == "save":
		GameState.save_game(slot)
		GameState.notice.emit("บันทึกลงช่อง %d แล้ว" % slot)
		refresh()
		saved.emit(slot)
	elif GameState.load_game(slot):
		loaded.emit(slot)
