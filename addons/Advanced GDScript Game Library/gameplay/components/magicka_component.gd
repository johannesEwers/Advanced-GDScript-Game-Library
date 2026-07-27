# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name MagickaComponent
extends Node
## Reusable magicka state for characters and other magicka-using game objects.
##
## Spell casting, ability execution, cost calculations, cooldowns, regeneration
## rules, UI, and animations should remain in separate systems. This component
## only owns magicka and its state transitions.


## Emitted after the magicka value changed.
signal magicka_changed(
	current_magicka: float,
	previous_magicka: float,
	maximum_magicka: float
)

## Emitted after magicka was consumed. [param amount] is the actual magicka
## loss after clamping, not necessarily the requested amount.
signal consumed(amount: float, source: Variant)

## Emitted after magicka was restored. [param amount] is the actual magicka
## gain after clamping, not necessarily the requested amount.
signal restored(amount: float, source: Variant)

## Emitted when magicka changes from above zero to zero.
signal depleted(source: Variant)

## Emitted when magicka changes from zero to above zero.
signal recovered(current_magicka: float, source: Variant)

## Emitted when maximum magicka changes at runtime.
signal maximum_magicka_changed(
	maximum_magicka: float,
	previous_maximum_magicka: float
)

const MINIMUM_MAX_MAGICKA := 0.001

var _maximum_magicka: float = 100.0
var _initialized := false

## Maximum magicka. When reduced at runtime, current magicka is clamped to it.
## Use [method set_maximum_magicka] when the current magicka ratio should be
## kept.
@export_range(0.001, 1_000_000.0, 0.1, "or_greater")
var maximum_magicka: float = 100.0:
	get:
		return _maximum_magicka
	set(value):
		_assign_maximum_magicka(value, false)

## If enabled, the component starts with maximum magicka.
@export var start_at_maximum_magicka := true

## Used only when [member start_at_maximum_magicka] is disabled.
@export_range(0.0, 1_000_000.0, 0.1, "or_greater")
var initial_magicka := 100.0

## Current magicka. Change it through the public methods.
var current_magicka: float = 0.0:
	set(value):
		current_magicka = clampf(value, 0.0, maximum_magicka)

## True while current magicka is zero.
var is_depleted: bool:
	get:
		return current_magicka <= 0.0

## Current magicka as a value from 0.0 to 1.0.
var magicka_ratio: float:
	get:
		return current_magicka / maximum_magicka


func _ready() -> void:
	_initialized = true
	current_magicka = (
		maximum_magicka if start_at_maximum_magicka
		else clampf(initial_magicka, 0.0, maximum_magicka)
	)


## Returns whether the complete positive [param amount] can be consumed.
##
## Use this for checks without changing state. For an atomic check-and-consume
## operation, use [method try_consume].
func can_consume(amount: float) -> bool:
	if amount <= 0.0:
		return false

	return current_magicka >= amount or is_equal_approx(current_magicka, amount)


## Consumes a positive amount and returns the actual magicka loss.
##
## If less magicka is available than requested, the remaining magicka is
## consumed and returned. Use [method try_consume] when partial consumption must
## not occur.
func consume(amount: float, source: Variant = null) -> float:
	if amount <= 0.0 or is_depleted:
		return 0.0

	var previous_magicka := current_magicka
	current_magicka = previous_magicka - amount
	var consumed_magicka := previous_magicka - current_magicka

	if is_zero_approx(consumed_magicka):
		return 0.0

	magicka_changed.emit(current_magicka, previous_magicka, maximum_magicka)
	consumed.emit(consumed_magicka, source)

	if is_depleted:
		depleted.emit(source)

	return consumed_magicka


## Consumes the complete positive [param amount] only if enough magicka exists.
##
## Returns true if the requested amount was consumed. No state or signal
## changes occur when the amount is invalid or insufficient.
func try_consume(amount: float, source: Variant = null) -> bool:
	if not can_consume(amount):
		return false

	consume(amount, source)
	return true


## Restores a positive amount and returns the actual magicka gain.
func restore(amount: float, source: Variant = null) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_magicka := current_magicka
	current_magicka = previous_magicka + amount
	var restored_magicka := current_magicka - previous_magicka

	if is_zero_approx(restored_magicka):
		return 0.0

	magicka_changed.emit(current_magicka, previous_magicka, maximum_magicka)
	restored.emit(restored_magicka, source)

	if previous_magicka <= 0.0 and current_magicka > 0.0:
		recovered.emit(current_magicka, source)

	return restored_magicka


## Sets magicka directly and returns the signed change.
##
## This does not emit [signal consumed] or [signal restored]. It does emit
## depletion or recovery transitions.
func set_magicka(value: float, source: Variant = null) -> float:
	var previous_magicka := current_magicka
	current_magicka = value
	var change := current_magicka - previous_magicka

	if is_zero_approx(change):
		return 0.0

	magicka_changed.emit(current_magicka, previous_magicka, maximum_magicka)

	if previous_magicka > 0.0 and current_magicka <= 0.0:
		depleted.emit(source)
	elif previous_magicka <= 0.0 and current_magicka > 0.0:
		recovered.emit(current_magicka, source)

	return change


## Changes maximum magicka. If [param preserve_ratio] is true, the current
## magicka percentage is preserved; otherwise, only values above the new
## maximum are clamped.
func set_maximum_magicka(value: float, preserve_ratio := false) -> void:
	_assign_maximum_magicka(value, preserve_ratio)


## Sets magicka to zero and returns whether the state changed.
func deplete(source: Variant = null) -> bool:
	if is_depleted:
		return false

	set_magicka(0.0, source)
	return true


## Restores maximum magicka.
func reset_magicka(source: Variant = null) -> void:
	set_magicka(maximum_magicka, source)


func _assign_maximum_magicka(value: float, preserve_ratio: bool) -> void:
	var new_maximum := maxf(value, MINIMUM_MAX_MAGICKA)

	if is_equal_approx(_maximum_magicka, new_maximum):
		return

	var previous_maximum := _maximum_magicka
	var previous_magicka := current_magicka
	var previous_ratio := previous_magicka / previous_maximum

	_maximum_magicka = new_maximum

	if not _initialized:
		return

	if preserve_ratio:
		current_magicka = previous_ratio * _maximum_magicka
	else:
		current_magicka = minf(previous_magicka, _maximum_magicka)

	maximum_magicka_changed.emit(_maximum_magicka, previous_maximum)

	if not is_equal_approx(current_magicka, previous_magicka):
		magicka_changed.emit(current_magicka, previous_magicka, _maximum_magicka)
