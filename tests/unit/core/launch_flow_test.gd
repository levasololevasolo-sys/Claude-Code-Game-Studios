## Regression (BUG: a launch started straight in location 1): a normal launch
## opens the main menu and begins in the base; scripted checks keep their old start.
extends GdUnitTestSuite

func test_normal_launch_opens_main_menu() -> void:
	assert_bool(World.wants_main_menu(PackedStringArray(), false)).is_true()

func test_checks_and_save_arg_skip_main_menu() -> void:
	assert_bool(World.wants_main_menu(PackedStringArray(["--run-check=x"]), false)).is_false()
	assert_bool(World.wants_main_menu(PackedStringArray([]), true)).is_false()
	assert_bool(World.wants_main_menu(PackedStringArray(["--skip-menu"]), false)).is_false()

func test_menu_check_keeps_the_menu() -> void:
	assert_bool(World.wants_main_menu(PackedStringArray(["--menu-check=x"]), false)).is_true()

func test_normal_launch_begins_in_base() -> void:
	assert_bool(RunDirector.starts_at_base(PackedStringArray())).is_true()

func test_checks_begin_in_a_run() -> void:
	assert_bool(RunDirector.starts_at_base(PackedStringArray(["--run-check=x"]))).is_false()
	assert_bool(RunDirector.starts_at_base(PackedStringArray(["--demo=x"]))).is_false()

func test_slot_line_empty_and_full() -> void:
	assert_str(MainMenu.slot_line(2, {})).is_equal("Слот 2 · Пусто")
	assert_str(MainMenu.slot_line(3, { "runs": 12, "embers": 340, "difficulty": "" })).is_equal("Слот 3 · забегов 12 · угли 340")

func test_slot_paths() -> void:
	assert_str(SaveSlots.slot_path(1)).is_equal("user://slot_1.json")
	assert_str(SaveSlots.slot_path(9)).is_equal("user://slot_5.json")
