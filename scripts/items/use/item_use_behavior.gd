class_name ItemUseBehavior
extends Resource
## What an item does when it is used from the right-click menu (使用).
## Subclasses implement use(); the caller (InventoryActions) removes one
## item from the used stack afterwards. New kinds of use = new subclass.


## Apply the effect for `user` (the player). Returns "" on success or a
## short reason why nothing happened (then nothing is consumed).
func use(_item: ItemData, _user: Node) -> String:
	return "现在用不了。"
