# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name InventoryEntry
extends Resource
## One stack stored by an [InventoryComponent].
##
## Runtime inventories duplicate entries before modifying them, so the
## resources assigned as initial contents remain unchanged.


## Shared item definition represented by this stack.
@export var item: InventoryItemDefinition

## Number of units in this stack.
@export_range(1, 2_147_483_647, 1, "or_greater")
var amount: int = 1:
	set(value):
		amount = maxi(value, 1)


func _init(item_definition: InventoryItemDefinition = null, initial_amount: int = 1) -> void:
	item = item_definition
	amount = initial_amount


## Creates an independent entry that refers to the same immutable item
## definition.
func copy() -> InventoryEntry:
	return InventoryEntry.new(item, amount)
