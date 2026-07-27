# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name StaminaComponent
extends Node
## Reusable stamina state for characters and other stamina-using game objects.
##
## Input, movement, action execution, cooldowns, regeneration rules, UI, and
## animations should remain in separate systems. This component only owns
## stamina and its state transitions.


## Emitted after the stamina value changed.
signal stamina_changed(
	current_stamina: float,
	previous_stamina: float,
	maximum_stamina: float
)

## Emitted after stamina was consumed. [param amount] is the actual stamina
## loss after clamping, not necessarily the requested amount.
signal consumed(amount: float, source: Variant)

## Emitted after stamina was restored. [param amount] is the actual stamina
## gain after clamping, not necessarily the requested amount.
signal restored(amount: float, source: Variant)

## Emitted when stamina changes from above zero to zero.
signal depleted(source: Variant)

## Emitted when stamina changes from zero to above zero.
signal recovered(current_stamina: float, source: Variant)

## Emitted when maximum stamina changes at runtime.
signal maximum_stamina_changed(
	maximum_stamina: float,
	previous_maximum_stamina: float
)

const MINIMUM_MAX_STAMINA := 0.001

var _maximum_stamina: float = 100.0
var _initialized := false

## Maximum stamina. When reduced at runtime, current stamina is clamped to it.
## Use [method set_maximum_stamina] when the current stamina ratio should be
## kept.
@export_range(0.001, 1_000_000.0, 0.1, "or_greater")
var maximum_stamina: float = 100.0:
	get:
		return _maximum_stamina
	set(value):
		_assign_maximum_stamina(value, false)

## If enabled, the component starts with maximum stamina.
@export var start_at_maximum_stamina := true

## Used only when [member start_at_maximum_stamina] is disabled.
@export_range(0.0, 1_000_000.0, 0.1, "or_greater")
var initial_stamina := 100.0

## Current stamina. Change it through the public methods.
var current_stamina: float = 0.0:
	set(value):
		current_stamina = clampf(value, 0.0, maximum_stamina)

## True while current stamina is zero.
var is_depleted: bool:
	get:
		return current_stamina <= 0.0

## Current stamina as a value from 0.0 to 1.0.
var stamina_ratio: float:
	get:
		return current_stamina / maximum_stamina


func _ready() -> void:
	_initialized = true
	current_stamina = (
		maximum_stamina if start_at_maximum_stamina
		else clampf(initial_stamina, 0.0, maximum_stamina)
	)


## Returns whether the complete positive [param amount] can be consumed.
##
## Use this for checks without changing state. For an atomic check-and-consume
## operation, use [method try_consume].
func can_consume(amount: float) -> bool:
	if amount <= 0.0:
		return false

	return current_stamina >= amount or is_equal_approx(current_stamina, amount)


## Consumes a positive amount and returns the actual stamina loss.
##
## If less stamina is available than requested, the remaining stamina is
## consumed and returned. Use [method try_consume] when partial consumption must
## not occur.
func consume(amount: float, source: Variant = null) -> float:
	if amount <= 0.0 or is_depleted:
		return 0.0

	var previous_stamina := current_stamina
	current_stamina = previous_stamina - amount
	var consumed_stamina := previous_stamina - current_stamina

	if is_zero_approx(consumed_stamina):
		return 0.0

	stamina_changed.emit(current_stamina, previous_stamina, maximum_stamina)
	consumed.emit(consumed_stamina, source)

	if is_depleted:
		depleted.emit(source)

	return consumed_stamina


## Consumes the complete positive [param amount] only if enough stamina exists.
##
## Returns true if the requested amount was consumed. No state or signal
## changes occur when the amount is invalid or insufficient.
func try_consume(amount: float, source: Variant = null) -> bool:
	if not can_consume(amount):
		return false

	consume(amount, source)
	return true


## Restores a positive amount and returns the actual stamina gain.
func restore(amount: float, source: Variant = null) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_stamina := current_stamina
	current_stamina = previous_stamina + amount
	var restored_stamina := current_stamina - previous_stamina

	if is_zero_approx(restored_stamina):
		return 0.0

	stamina_changed.emit(current_stamina, previous_stamina, maximum_stamina)
	restored.emit(restored_stamina, source)

	if previous_stamina <= 0.0 and current_stamina > 0.0:
		recovered.emit(current_stamina, source)

	return restored_stamina


## Sets stamina directly and returns the signed change.
##
## This does not emit [signal consumed] or [signal restored]. It does emit
## depletion or recovery transitions.
func set_stamina(value: float, source: Variant = null) -> float:
	var previous_stamina := current_stamina
	current_stamina = value
	var change := current_stamina - previous_stamina

	if is_zero_approx(change):
		return 0.0

	stamina_changed.emit(current_stamina, previous_stamina, maximum_stamina)

	if previous_stamina > 0.0 and current_stamina <= 0.0:
		depleted.emit(source)
	elif previous_stamina <= 0.0 and current_stamina > 0.0:
		recovered.emit(current_stamina, source)

	return change


## Changes maximum stamina. If [param preserve_ratio] is true, the current
## stamina percentage is preserved; otherwise, only values above the new
## maximum are clamped.
func set_maximum_stamina(value: float, preserve_ratio := false) -> void:
	_assign_maximum_stamina(value, preserve_ratio)


## Sets stamina to zero and returns whether the state changed.
func deplete(source: Variant = null) -> bool:
	if is_depleted:
		return false

	set_stamina(0.0, source)
	return true


## Restores maximum stamina.
func reset_stamina(source: Variant = null) -> void:
	set_stamina(maximum_stamina, source)


func _assign_maximum_stamina(value: float, preserve_ratio: bool) -> void:
	var new_maximum := maxf(value, MINIMUM_MAX_STAMINA)

	if is_equal_approx(_maximum_stamina, new_maximum):
		return

	var previous_maximum := _maximum_stamina
	var previous_stamina := current_stamina
	var previous_ratio := previous_stamina / previous_maximum

	_maximum_stamina = new_maximum

	if not _initialized:
		return

	if preserve_ratio:
		current_stamina = previous_ratio * _maximum_stamina
	else:
		current_stamina = minf(previous_stamina, _maximum_stamina)

	maximum_stamina_changed.emit(_maximum_stamina, previous_maximum)

	if not is_equal_approx(current_stamina, previous_stamina):
		stamina_changed.emit(current_stamina, previous_stamina, _maximum_stamina)
