class_name SaveSlots
extends VBoxContainer
## Save / load slot list written on a notebook page (in-game menu) or a paper
## note (title screen). Slot 0 is the autosave (load only).

signal loaded(slot: int)
signal saved(slot: int)

var mode := "load"


func _init(m := "load") -> void:
	mode = m
	add_theme_constant_override("separation", 4)


func _ready() -> void:
	refresh()


func refresh() -> void:
	UiKit.clear(self)
	add_child(UiKit.hand_label("บันทึกเกม" if mode == "save" else "โหลดเกม", 46, UiKit.RED_INK))
	add_child(
		UiKit.hand_label(
			"แตะช่องที่จะเขียนทับ" if mode == "save" else "แตะช่องที่จะเล่นต่อ", 28, UiKit.INK_FADED
		)
	)
	var saves := GameState.list_saves()
	var first := 1 if mode == "save" else 0
	for slot in range(first, GameState.SAVE_SLOTS + 1):
		var meta: Dictionary = saves.get(slot, {})
		var name := "ออโต้เซฟ" if slot == 0 else "ช่อง %d" % slot
		var info := "— ว่าง —"
		if not meta.is_empty():
			info = (
				"บทที่ %d · %s"
				% [int(meta.get("chapter", 1)), str(meta.get("place", "")).get_slice(" · ", 0)]
			)
		var b := UiKit.hand_button("%s   %s" % [name, info], _on_slot.bind(slot), 34)
		b.name = "Slot%d" % slot
		b.custom_minimum_size = Vector2(0, 64)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
