# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name InventoryItemDefinition
extends Resource
## Immutable design data shared by inventory entries.
##
## Treat instances of this resource as definitions, not as runtime item
## instances. Per-instance state such as durability should be stored in a
## separate item-instance resource.


## Stable identifier used to compare, count, remove, and transfer items.
@export var item_id: StringName = &""

## User-facing name. Inventory logic does not depend on this value.
@export var display_name: String = ""

## Optional user-facing description.
@export_multiline var description: String = ""

## Optional icon for inventory user interfaces.
@export var icon: Texture2D

## Maximum number of units stored in one inventory slot.
@export_range(1, 2_147_483_647, 1, "or_greater")
var maximum_stack_size: int = 1:
	set(value):
		maximum_stack_size = maxi(value, 1)

## Weight of one unit. Zero means that the item consumes no weight capacity.
@export_range(0.0, 1_000_000.0, 0.01, "or_greater")
var unit_weight: float = 0.0:
	set(value):
		unit_weight = maxf(value, 0.0)

## Optional classification data for filters, equipment rules, or crafting.
@export var tags: Array[StringName] = []


## Returns whether this definition has the minimum data required by an
## [InventoryComponent].
func is_valid() -> bool:
	return item_id != &"" and maximum_stack_size > 0 and unit_weight >= 0.0
