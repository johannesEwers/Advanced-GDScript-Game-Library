# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name InventoryComponent
extends Node
## Reusable inventory state for actors, containers, and loot sources.
##
## This component is independent of input, physics, user interfaces, and world
## pickup detection. A player, enemy, NPC, chest, or dropped loot object can own
## it as a child node. Other systems interact through the public methods and
## signals below.
##
## A capacity value of zero means unlimited. Items with the same
## [InventoryItemDefinition.item_id] are treated as the same item type.


## Emitted after units were added.
##
## [param source] is passed through unchanged and may identify the pickup,
## inventory, actor, or system responsible for the operation.
signal item_added(
	item: InventoryItemDefinition,
	amount: int,
	source: Variant
)

## Emitted after units were removed.
##
## [param destination] is passed through unchanged and may identify the
## receiving inventory, consumer, actor, or system.
signal item_removed(
	item: InventoryItemDefinition,
	amount: int,
	destination: Variant
)

## Emitted after the total quantity of one item type changed.
signal item_quantity_changed(
	item: InventoryItemDefinition,
	current_amount: int,
	previous_amount: int
)

## Emitted once after any successful content mutation.
signal inventory_changed()

## Emitted after occupied slots, current weight, or configured limits changed.
signal capacity_changed(
	occupied_slots: int,
	maximum_slots: int,
	current_weight: float,
	maximum_weight: float
)

## Emitted when an add request could not be fulfilled completely.
##
## [param rejected_amount] contains only the units that were not accepted.
signal item_rejected(
	item: InventoryItemDefinition,
	rejected_amount: int,
	reason: StringName
)


const REJECTION_INVALID_ITEM: StringName = &"invalid_item"
const REJECTION_INVALID_AMOUNT: StringName = &"invalid_amount"
const REJECTION_SLOT_CAPACITY: StringName = &"slot_capacity"
const REJECTION_WEIGHT_CAPACITY: StringName = &"weight_capacity"
const REJECTION_MUTATION_IN_PROGRESS: StringName = &"mutation_in_progress"

const UNLIMITED_CAPACITY: int = 0
const WEIGHT_EPSILON: float = 0.00001


## Maximum number of occupied slots. Zero means unlimited.
@export_range(0, 1_000_000, 1, "or_greater")
var maximum_slots: int = UNLIMITED_CAPACITY:
	set(value):
		var normalized_value := maxi(value, UNLIMITED_CAPACITY)
		if maximum_slots == normalized_value:
			return
		maximum_slots = normalized_value
		_emit_capacity_changed()

## Maximum combined item weight. Zero means unlimited.
@export_range(0.0, 1_000_000.0, 0.01, "or_greater")
var maximum_weight: float = float(UNLIMITED_CAPACITY):
	set(value):
		var normalized_value := maxf(value, float(UNLIMITED_CAPACITY))
		if is_equal_approx(maximum_weight, normalized_value):
			return
		maximum_weight = normalized_value
		_emit_capacity_changed()

## Entries copied into the runtime inventory when this node becomes ready.
##
## Invalid entries and quantities exceeding the configured capacities are
## ignored or truncated.
@export var initial_entries: Array[InventoryEntry] = []

var _entries: Array[InventoryEntry] = []
var _mutation_in_progress: bool = false


func _ready() -> void:
	reset_to_initial_entries()


## Returns independent snapshots of all current stacks.
##
## Mutating the returned entries does not mutate this inventory.
func get_entries() -> Array[InventoryEntry]:
	var result: Array[InventoryEntry] = []
	for entry in _entries:
		result.append(entry.copy())
	return result


## Returns the number of occupied inventory slots.
func get_occupied_slot_count() -> int:
	return _entries.size()


## Returns the combined weight of all stored item units.
func get_current_weight() -> float:
	var total_weight := 0.0
	for entry in _entries:
		total_weight += entry.item.unit_weight * entry.amount
	return total_weight


## Returns the total number of units matching [param item_id].
func get_item_amount(item_id: StringName) -> int:
	var total_amount := 0
	for entry in _entries:
		if entry.item.item_id == item_id:
			total_amount += entry.amount
	return total_amount


## Returns the definition currently associated with [param item_id], or
## [code]null[/code] if the inventory does not contain that item.
func get_item_definition(item_id: StringName) -> InventoryItemDefinition:
	for entry in _entries:
		if entry.item.item_id == item_id:
			return entry.item
	return null


## Returns whether at least [param amount] matching units are stored.
func has_item(item_id: StringName, amount: int = 1) -> bool:
	return amount > 0 and get_item_amount(item_id) >= amount


## Returns whether the complete requested quantity can be added.
func can_add_item(item: InventoryItemDefinition, amount: int = 1) -> bool:
	return amount > 0 and get_addable_amount(item, amount) == amount


## Returns how many units from the requested quantity currently fit.
func get_addable_amount(item: InventoryItemDefinition, requested_amount: int) -> int:
	if not _is_valid_item(item) or requested_amount <= 0:
		return 0

	var addable_amount := requested_amount
	addable_amount = mini(
		addable_amount,
		_get_slot_limited_amount(item, requested_amount)
	)
	addable_amount = mini(
		addable_amount,
		_get_weight_limited_amount(item, requested_amount)
	)
	return maxi(addable_amount, 0)


## Adds as many requested units as the configured capacities permit.
##
## Existing stacks are filled before new slots are created. Returns the actual
## number of units added. A partial addition emits [signal item_rejected] for
## the remainder.
func add_item(item: InventoryItemDefinition, requested_amount: int = 1, source: Variant = null) -> int:
	if _mutation_in_progress:
		_emit_rejection(
			item,
			requested_amount,
			REJECTION_MUTATION_IN_PROGRESS
		)
		return 0
	if not _is_valid_item(item):
		_emit_rejection(item, requested_amount, REJECTION_INVALID_ITEM)
		return 0
	if requested_amount <= 0:
		_emit_rejection(item, requested_amount, REJECTION_INVALID_AMOUNT)
		return 0

	var accepted_amount := get_addable_amount(item, requested_amount)
	var previous_amount := get_item_amount(item.item_id)

	if accepted_amount > 0:
		_mutation_in_progress = true
		_add_unchecked(item, accepted_amount)
		_mutation_in_progress = false
		_emit_added(item, accepted_amount, previous_amount, source)

	var rejected_amount := requested_amount - accepted_amount
	if rejected_amount > 0:
		_emit_rejection(
			item,
			rejected_amount,
			_get_capacity_rejection_reason(item)
		)

	return accepted_amount


## Removes up to the requested number of matching units.
##
## Returns the actual number removed. Requesting more than is present removes
## all matching units.
func remove_item(item_id: StringName, requested_amount: int = 1, destination: Variant = null) -> int:
	if _mutation_in_progress or item_id == &"" or requested_amount <= 0:
		return 0

	var item := get_item_definition(item_id)
	if item == null:
		return 0

	var previous_amount := get_item_amount(item_id)
	var removed_amount := mini(requested_amount, previous_amount)
	if removed_amount <= 0:
		return 0

	_mutation_in_progress = true
	_remove_unchecked(item_id, removed_amount)
	_mutation_in_progress = false
	_emit_removed(item, removed_amount, previous_amount, destination)
	return removed_amount


## Transfers up to the requested number of units to another inventory.
##
## Both inventories are changed before signals are emitted, so signal listeners
## observe a consistent transfer result. Returns the number of transferred
## units.
func transfer_item_to(target: InventoryComponent, item_id: StringName, requested_amount: int = 1) -> int:
	if (
		target == null
		or target == self
		or _mutation_in_progress
		or target._mutation_in_progress
		or item_id == &""
		or requested_amount <= 0
	):
		return 0

	var item := get_item_definition(item_id)
	if item == null:
		return 0

	var source_previous_amount := get_item_amount(item_id)
	var target_previous_amount := target.get_item_amount(item_id)
	var transferable_amount := mini(requested_amount, source_previous_amount)
	transferable_amount = mini(
		transferable_amount,
		target.get_addable_amount(item, transferable_amount)
	)
	if transferable_amount <= 0:
		target._emit_rejection(
			item,
			mini(requested_amount, source_previous_amount),
			target._get_capacity_rejection_reason(item)
		)
		return 0

	_mutation_in_progress = true
	target._mutation_in_progress = true
	_remove_unchecked(item_id, transferable_amount)
	target._add_unchecked(item, transferable_amount)
	target._mutation_in_progress = false
	_mutation_in_progress = false

	_emit_removed(
		item,
		transferable_amount,
		source_previous_amount,
		target
	)
	target._emit_added(
		item,
		transferable_amount,
		target_previous_amount,
		self
	)

	var rejected_amount := mini(
		requested_amount,
		source_previous_amount
	) - transferable_amount
	if rejected_amount > 0:
		target._emit_rejection(
			item,
			rejected_amount,
			target._get_capacity_rejection_reason(item)
		)

	return transferable_amount


## Transfers as many units as possible from every item type to [param target].
##
## The returned dictionary maps item identifiers to transferred quantities.
## Items that do not fit remain in this inventory.
func transfer_all_to(target: InventoryComponent) -> Dictionary:
	var transferred: Dictionary = {}
	if target == null or target == self:
		return transferred

	var item_ids: Array[StringName] = []
	for entry in _entries:
		if not item_ids.has(entry.item.item_id):
			item_ids.append(entry.item.item_id)

	for item_id in item_ids:
		var transferred_amount := transfer_item_to(
			target,
			item_id,
			get_item_amount(item_id)
		)
		if transferred_amount > 0:
			transferred[item_id] = transferred_amount

	return transferred


## Convenience inverse of [method transfer_all_to].
##
## This is useful when a player, enemy, or NPC loots a chest or dropped
## inventory.
func take_all_from(source: InventoryComponent) -> Dictionary:
	if source == null:
		return {}
	return source.transfer_all_to(self)


## Removes all contents and emits one removal event per item type.
func clear(destination: Variant = null) -> void:
	if _mutation_in_progress or _entries.is_empty():
		return

	var removed_by_id: Dictionary = {}
	var definitions_by_id: Dictionary = {}
	for entry in _entries:
		var item_id := entry.item.item_id
		removed_by_id[item_id] = (
			int(removed_by_id.get(item_id, 0)) + entry.amount
		)
		definitions_by_id[item_id] = entry.item

	_mutation_in_progress = true
	_entries.clear()
	_mutation_in_progress = false

	for dictionary_key in removed_by_id:
		var item_id: StringName = dictionary_key
		var item: InventoryItemDefinition = definitions_by_id[item_id]
		var removed_amount: int = removed_by_id[item_id]
		item_quantity_changed.emit(item, 0, removed_amount)
		item_removed.emit(item, removed_amount, destination)

	inventory_changed.emit()
	_emit_capacity_changed()


## Rebuilds the runtime inventory from duplicated [member initial_entries].
func reset_to_initial_entries() -> void:
	if _mutation_in_progress:
		return

	_mutation_in_progress = true
	_entries.clear()
	for initial_entry in initial_entries:
		if (
			initial_entry == null
			or not _is_valid_item(initial_entry.item)
			or initial_entry.amount <= 0
		):
			continue
		var accepted_amount := get_addable_amount(
			initial_entry.item,
			initial_entry.amount
		)
		if accepted_amount > 0:
			_add_unchecked(initial_entry.item, accepted_amount)
	_mutation_in_progress = false

	inventory_changed.emit()
	_emit_capacity_changed()


## Returns whether the current contents exceed a limit.
##
## This can occur when a limit is reduced after items were stored.
func is_over_capacity() -> bool:
	var slots_exceeded := (
		maximum_slots > UNLIMITED_CAPACITY
		and get_occupied_slot_count() > maximum_slots
	)
	var weight_exceeded := (
		maximum_weight > float(UNLIMITED_CAPACITY)
		and get_current_weight() > maximum_weight + WEIGHT_EPSILON
	)
	return slots_exceeded or weight_exceeded


func _is_valid_item(item: InventoryItemDefinition) -> bool:
	return item != null and item.is_valid()


func _get_slot_limited_amount(item: InventoryItemDefinition, requested_amount: int) -> int:
	var existing_stack_space := 0
	for entry in _entries:
		if entry.item.item_id == item.item_id:
			existing_stack_space += maxi(
				item.maximum_stack_size - entry.amount,
				0
			)

	if maximum_slots == UNLIMITED_CAPACITY:
		return requested_amount

	var available_slots := maxi(maximum_slots - _entries.size(), 0)
	var total_space := (
		existing_stack_space
		+ available_slots * item.maximum_stack_size
	)
	return mini(requested_amount, total_space)


func _get_weight_limited_amount(item: InventoryItemDefinition, requested_amount: int) -> int:
	if (
		maximum_weight <= float(UNLIMITED_CAPACITY)
		or is_zero_approx(item.unit_weight)
	):
		return requested_amount

	var available_weight := maxf(
		maximum_weight - get_current_weight(),
		0.0
	)
	var weight_limited_amount := int(
		floor(
			(available_weight + WEIGHT_EPSILON)
			/ item.unit_weight
		)
	)
	return mini(requested_amount, weight_limited_amount)


func _get_capacity_rejection_reason(item: InventoryItemDefinition) -> StringName:
	if _get_weight_limited_amount(item, 1) == 0:
		return REJECTION_WEIGHT_CAPACITY
	return REJECTION_SLOT_CAPACITY


func _add_unchecked(item: InventoryItemDefinition, amount_to_add: int) -> void:
	var remaining_amount := amount_to_add

	for entry in _entries:
		if entry.item.item_id != item.item_id:
			continue
		var stack_space := maxi(
			item.maximum_stack_size - entry.amount,
			0
		)
		var stack_addition := mini(remaining_amount, stack_space)
		entry.amount += stack_addition
		remaining_amount -= stack_addition
		if remaining_amount == 0:
			return

	while remaining_amount > 0:
		var stack_amount := mini(
			remaining_amount,
			item.maximum_stack_size
		)
		_entries.append(InventoryEntry.new(item, stack_amount))
		remaining_amount -= stack_amount


func _remove_unchecked(item_id: StringName, amount_to_remove: int) -> void:
	var remaining_amount := amount_to_remove
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		if entry.item.item_id != item_id:
			continue

		var stack_removal := mini(remaining_amount, entry.amount)
		remaining_amount -= stack_removal
		if stack_removal == entry.amount:
			_entries.remove_at(index)
		else:
			entry.amount -= stack_removal

		if remaining_amount == 0:
			return


func _emit_added(item: InventoryItemDefinition, added_amount: int, previous_amount: int, source: Variant) -> void:
	item_quantity_changed.emit(
		item,
		previous_amount + added_amount,
		previous_amount
	)
	item_added.emit(item, added_amount, source)
	inventory_changed.emit()
	_emit_capacity_changed()


func _emit_removed(item: InventoryItemDefinition, removed_amount: int, previous_amount: int, destination: Variant) -> void:
	item_quantity_changed.emit(
		item,
		previous_amount - removed_amount,
		previous_amount
	)
	item_removed.emit(item, removed_amount, destination)
	inventory_changed.emit()
	_emit_capacity_changed()


func _emit_rejection(item: InventoryItemDefinition, rejected_amount: int, reason: StringName) -> void:
	if rejected_amount > 0:
		item_rejected.emit(item, rejected_amount, reason)


func _emit_capacity_changed() -> void:
	capacity_changed.emit(
		get_occupied_slot_count(),
		maximum_slots,
		get_current_weight(),
		maximum_weight
	)
