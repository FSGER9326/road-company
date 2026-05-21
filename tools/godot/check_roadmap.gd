extends SceneTree
const DataStoreScript = preload("res://game/scripts/core/DataStore.gd")
func _init():
    var data = DataStoreScript.new()
    data.load_all()
    var tex = data.load_asset_texture("icon_danger_1")
    print("icon_danger_1 texture: ", tex != null)
    var tex2 = data.load_asset_texture("icon_settlement_town")
    print("icon_settlement_town texture: ", tex2 != null)
    quit(0)
