extends SceneTree
func _init():
    var path = "res://assets/generated/tokens/token_fighter_01.svg"
    print("ResourceLoader.exists: ", ResourceLoader.exists(path))
    print("FileAccess.file_exists: ", FileAccess.file_exists(path))
    if FileAccess.file_exists(path):
        var s = FileAccess.get_file_as_string(path)
        var img = Image.new()
        var err = img.load_svg_from_string(s)
        print("load_svg_from_string: ", err == OK)
    quit(0)
