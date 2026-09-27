class_name DiaryWriter
extends RefCounted
## Builds diary pages from what actually happened. Plain templates — the
## diary is the brother's record, not a statistics screen.

const FIRST_DAY := [
	"今天还是去了学校旁边的便利店。",
	"搜集到了一些能够撑一阵子的物资。",
	"妹妹的哮喘药已经不多了。",
	"还好这附近似乎没什么人来，没有人跟我们抢物资。",
	"不过……",
	"没有药的话，",
	"妹妹的哮喘病又怎么办呢……",
]
const MAX_KINDS := 3


static func first_day() -> PackedStringArray:
	return PackedStringArray(FIRST_DAY)


## gains: {item_id: count} brought home today. rare: [item_id] first found today.
static func daily(gains: Dictionary, rare: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	# group ordinary items by their diary name, biggest amounts first
	var kinds := {}
	for id in gains:
		if id in rare or StringName(id) in GameState.RARE_ITEMS:
			continue
		var it := item(id)
		if it == null:
			continue
		var n := it.diary_name if it.diary_name != "" else it.display_name
		kinds[n] = int(kinds.get(n, 0)) + int(gains[id])
	var names: Array = kinds.keys()
	names.sort_custom(func(a, b): return kinds[a] > kinds[b])
	names = names.slice(0, MAX_KINDS)
	if names.is_empty():
		lines.append("今天什么也没找到。")
	else:
		lines.append("今天搜到了一些%s。" % join_names(names))
	var rare_names: Array = []
	for id in rare:
		var it := item(id)
		if it:
			rare_names.append(it.diary_name if it.diary_name != "" else it.display_name)
	if rare_names.size() == 1:
		lines.append("甚至还搜到了%s！" % rare_names[0])
	elif rare_names.size() > 1:
		lines.append("甚至还找到了%s！" % join_names(rare_names))
	if names.is_empty() and rare_names.is_empty():
		lines.append("妹妹说没关系。")
	else:
		lines.append("妹妹也很开心。")
	return lines


## ["水"] -> 水, ["水","食物"] -> 水和食物, ["水","食物","空瓶子"] -> 水、食物和空瓶子
static func join_names(names: Array) -> String:
	if names.size() == 1:
		return names[0]
	var head := "、".join(PackedStringArray(names.slice(0, names.size() - 1)))
	return "%s和%s" % [head, names[-1]]


static func item(id) -> ItemData:
	var p := "res://resources/items/%s.tres" % String(id)
	return load(p) as ItemData if ResourceLoader.exists(p) else null
