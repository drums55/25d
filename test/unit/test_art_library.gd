extends GutTest
## Drop-in art: missing files keep placeholders; a character folder becomes a
## CutoutSkin with sensible default pivots.

const ROOT := "user://art_test"
const CHAR_DIR := ROOT + "/characters/tester"
const RIG := preload("res://scenes/characters/cutout_rig.tscn")


func before_each():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHAR_DIR))


func after_each():
	var g := ProjectSettings.globalize_path(ROOT)
	for f in DirAccess.get_files_at(CHAR_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHAR_DIR).path_join(f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHAR_DIR))
	DirAccess.remove_absolute(g.path_join("characters"))
	DirAccess.remove_absolute(g)


func _png(part: String, w: int, h: int) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(CHAR_DIR.path_join(part + ".png"))


func test_missing_art_returns_null_and_keeps_placeholders():
	assert_null(ArtLibrary.prop("does_not_exist"))
	assert_null(ArtLibrary.room("does_not_exist"))
	assert_null(ArtLibrary.character("does_not_exist"))
	var rig := RIG.instantiate()
	rig.character_name = "does_not_exist"
	add_child_autofree(rig)
	assert_null(rig.skin)
	assert_true(rig.get_node("Skeleton2D/Hip/Torso/Placeholder").visible)


func test_default_pivots():
	assert_eq(ArtLibrary.default_pivot("head", Vector2(100, 120)), Vector2(50, 120))
	assert_eq(ArtLibrary.default_pivot("torso_back", Vector2(100, 120)), Vector2(50, 120))
	assert_eq(ArtLibrary.default_pivot("arm_l", Vector2(40, 110)), Vector2(20, 0))
	assert_eq(ArtLibrary.default_pivot("leg_r", Vector2(40, 140)), Vector2(20, 0))


func test_character_folder_becomes_skin_with_pivots_json_override():
	_png("head", 100, 120)
	_png("arm_r", 40, 110)
	var f := FileAccess.open(CHAR_DIR.path_join("pivots.json"), FileAccess.WRITE)
	f.store_string('{"head": [48, 115], "bogus": "x"}')
	f.close()
	var skin := ArtLibrary.character("tester", ROOT)
	assert_not_null(skin)
	assert_eq(skin.textures.size(), 2)
	assert_eq(skin.get_pivot("head"), Vector2(48, 115), "json override")
	assert_eq(skin.get_pivot("arm_r"), Vector2(20, 0), "default for arm")
	assert_null(skin.get_texture("leg_l"))
	assert_eq(skin.get_texture("head", true), skin.get_texture("head"), "no back art -> front")


func test_rig_applies_skin_hides_placeholders_and_scales():
	_png("torso", 140, 140)
	var rig := RIG.instantiate()
	add_child_autofree(rig)
	rig.skin = ArtLibrary.character("tester", ROOT)
	var torso := rig.get_node("Skeleton2D/Hip/Torso")
	assert_false(torso.get_node("Placeholder").visible)
	var art := torso.get_node("Art") as Sprite2D
	assert_not_null(art)
	assert_eq(art.scale, Vector2.ONE / ArtLibrary.ART_SCALE)
	assert_eq(art.offset, Vector2(-70, -140), "torso hangs from bottom centre pivot")
	assert_false(rig.get_node("Skeleton2D/Hip/Torso/ArmR/Weapon").visible)
