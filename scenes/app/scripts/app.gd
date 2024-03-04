extends Control

@export var game_button: PackedScene
@export var button_offset: Vector2

var pid_watching: int = -1
var games: Dictionary

@onready var gradient_bg: TextureRect = $GradientBG
@onready var timer: Timer = Timer.new()
@onready var games_container: Control = $Games

func _ready() -> void:
	configure_timer()
	var base_dir: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	create_game_folder(base_dir)
	parse_games(base_dir.path_join("games"))
	create_game_buttons(games)
	
	# Test
	#launch_game("Dashpong")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("About to quit, killing process")
		if pid_watching > 0:
			OS.kill(pid_watching)
			
			# Maybe use a softer method, by sending a WM_CLOSE message first
			# windows only
			# NOT TESTED YET
			#taskkill /PID pid_watching
			#OS.execute(taskkill, ("/PID", str(pid_watching)])
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		print("Focus exit")
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		print("Focus enter")

func create_game_buttons(to_create: Dictionary) -> void:
	# TODO: create a carrousel container to handle everything
	var count: int = 0
	for key in to_create.keys():
		var instance: Button = game_button.instantiate()
		instance.game_name = key
		instance.properties = to_create[key]
		games_container.add_child(instance)
		instance.position -= instance.size / 2.0
		instance.position.x += (instance.size.x + button_offset.x) * count
		instance.focused.connect(on_game_btn_focused)
		instance.pressed.connect(on_game_btn_pressed.bind(instance))
		count += 1
	
	if games_container.get_child_count() < 0: return
	games_container.get_child(0).grab_focus()

func configure_timer() -> void:
	add_child(timer)
	# Configure the timer
	timer.one_shot = false
	timer.wait_time = 1.0
	timer.timeout.connect(on_timer_timeout)

func create_game_folder(base_dir: String) -> void:
	var dir = DirAccess.open(base_dir)
	if dir.dir_exists(base_dir.path_join("games")): return
	dir.make_dir(base_dir.path_join("games"))

func parse_games(path: String) -> void:
	var dir = DirAccess.open(path)
	
	dir.include_hidden = false
	dir.include_navigational = false
	
	if not dir: 
		print("An error occurred when trying to access the path.")
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# We found a game, explore its content
		if dir.current_is_dir():
			print("Found directory: " + file_name)
			games[file_name] = {}
			var subdir_path: String = path.path_join(file_name)
			var subdir = DirAccess.open(subdir_path)
			subdir.list_dir_begin()
			var file = subdir.get_next()
			while file != "":
				if not subdir.current_is_dir():
					var extension: String = file.get_extension()
					#TODO: make functionnal with other platforms
					match extension:
						"exe":
							print(subdir.get_current_dir())
							games[file_name]["executable"] = subdir.get_current_dir().path_join(file)
						"jpg", "jpeg", "png":
							if file.get_basename() == "capsule":
								games[file_name]["capsule"] = subdir.get_current_dir().path_join(file)
							elif file.get_basename() == "bg":
								games[file_name]["bg"] = subdir.get_current_dir().path_join(file)
					
				file = subdir.get_next()
			
		file_name = dir.get_next()
	print("Games: ", games)
	
func launch_game(game_name: String) -> void:
	if not games[game_name].has("executable"): return
	var executable_path: String = games[game_name]["executable"]
	pid_watching = OS.create_process(executable_path, [])
	#pid_watching = OS.create_process("C:\\Users\\Victor\\Documents\\dev\\TOOLS\\GameLauncher\\games\\Dashpong\\dashpong.exe", [])
	timer.start()

func on_timer_timeout() -> void:
	if OS.is_process_running(pid_watching):
		print("Running")
	else:
		print("Stopped")
		timer.stop()
		pid_watching = -1

func on_game_btn_focused(who: Button) -> void:
	if not who.properties.has("bg"): return
	var texture: ImageTexture = who.load_image_texture(who.properties["bg"])
	if not texture: return
	gradient_bg.texture = texture

func on_game_btn_pressed(btn: Button) -> void:
	launch_game(btn.game_name)
