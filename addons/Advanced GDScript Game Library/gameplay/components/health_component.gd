# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name HealthComponent
extends Node

## Reusable health state for characters and other damageable game objects.
##
## Damage calculation, armor, resistances, hit reactions, and animations should
## remain in separate components. This component only owns health and its state
## transitions.
##
## How to Use
## @onready var health: HealthComponent = $HealthComponent
##
## func _ready() -> void:
##	health.died.connect(_on_died)
##
## func receive_hit(amount: float, attacker: Node) -> void:
##	health.take_damage(amount, attacker)
##
## func _on_died(source: Variant) -> void:
##	queue_free()

## Emitted after the health value changed.
signal health_changed(
	current_health: float,
	previous_health: float,
	maximum_health: float
)

## Emitted after damage was applied. [param amount] is the actual health loss
## after clamping, not necessarily the requested damage.
signal damaged(amount: float, source: Variant)

## Emitted after healing was applied. [param amount] is the actual health gain
## after clamping, not necessarily the requested healing.
signal healed(amount: float, source: Variant)

## Emitted when health changes from above zero to zero.
signal died(source: Variant)

## Emitted when health changes from zero to above zero.
signal revived(current_health: float, source: Variant)

## Emitted when maximum health changes at runtime.
signal maximum_health_changed(maximum_health: float, previous_maximum_health: float)

const MINIMUM_MAX_HEALTH := 0.001

var _maximum_health: float = 100.0
var _initialized := false

## Maximum health. When reduced at runtime, current health is clamped to it.
## Use [method set_maximum_health] when the current health ratio should be kept.
@export_range(0.001, 1_000_000.0, 0.1, "or_greater")
var maximum_health: float = 100.0:
	get:
		return _maximum_health
	set(value):
		_assign_maximum_health(value, false)

## If enabled, the component starts with maximum health.
@export var start_at_maximum_health := true

## Used only when [member start_at_maximum_health] is disabled.
@export_range(0.0, 1_000_000.0, 0.1, "or_greater")
var initial_health := 100.0

## Prevents [method take_damage]. Explicit state changes such as
## [method set_health] and [method kill] still work.
@export var invulnerable := false

## If disabled, [method heal] cannot revive a dead object. Use
## [method revive] for an explicit revival.
@export var healing_can_revive := false

## Current health. Change it through the public methods.
var current_health: float = 0.0:
	set(value):
		current_health = clampf(value, 0.0, maximum_health)

## True while current health is zero.
var is_dead: bool:
	get:
		return current_health <= 0.0

## Current health as a value from 0.0 to 1.0.
var health_ratio: float:
	get:
		return current_health / maximum_health


func _ready() -> void:
	_initialized = true
	current_health = (
		maximum_health if start_at_maximum_health
		else clampf(initial_health, 0.0, maximum_health)
	)


## Applies positive damage and returns the actual health loss.
## Returns 0.0 if the component is dead, invulnerable, or the amount is invalid.
func take_damage(amount: float, source: Variant = null) -> float:
	if amount <= 0.0 or invulnerable or is_dead:
		return 0.0

	var previous_health := current_health
	current_health = previous_health - amount
	var applied_damage := previous_health - current_health

	if is_zero_approx(applied_damage):
		return 0.0

	health_changed.emit(current_health, previous_health, maximum_health)
	damaged.emit(applied_damage, source)

	if current_health <= 0.0:
		died.emit(source)

	return applied_damage


## Applies positive healing and returns the actual health gain.
## By default, dead objects must be revived explicitly with [method revive].
func heal(amount: float, source: Variant = null) -> float:
	if amount <= 0.0 or (is_dead and not healing_can_revive):
		return 0.0

	var previous_health := current_health
	current_health = previous_health + amount
	var applied_healing := current_health - previous_health

	if is_zero_approx(applied_healing):
		return 0.0

	health_changed.emit(current_health, previous_health, maximum_health)
	healed.emit(applied_healing, source)

	if previous_health <= 0.0 and current_health > 0.0:
		revived.emit(current_health, source)

	return applied_healing


## Sets health directly and returns the signed change.
## This bypasses invulnerability and does not emit [signal damaged] or
## [signal healed]. It does emit death or revival transitions.
func set_health(value: float, source: Variant = null) -> float:
	var previous_health := current_health
	current_health = value
	var change := current_health - previous_health

	if is_zero_approx(change):
		return 0.0

	health_changed.emit(current_health, previous_health, maximum_health)

	if previous_health > 0.0 and current_health <= 0.0:
		died.emit(source)
	elif previous_health <= 0.0 and current_health > 0.0:
		revived.emit(current_health, source)

	return change


## Changes maximum health. If [param preserve_ratio] is true, the current
## health percentage is preserved; otherwise, only values above the new maximum
## are clamped.
func set_maximum_health(value: float, preserve_ratio := false) -> void:
	_assign_maximum_health(value, preserve_ratio)


## Sets health to zero even while invulnerable.
func kill(source: Variant = null) -> bool:
	if is_dead:
		return false

	set_health(0.0, source)
	return true


## Revives a dead object with the requested positive health.
func revive(health: float = 1.0, source: Variant = null) -> bool:
	if not is_dead or health <= 0.0:
		return false

	set_health(health, source)
	return true


## Restores maximum health. This also revives a dead object.
func reset_health(source: Variant = null) -> void:
	set_health(maximum_health, source)


func _assign_maximum_health(value: float, preserve_ratio: bool) -> void:
	var new_maximum := maxf(value, MINIMUM_MAX_HEALTH)

	if is_equal_approx(_maximum_health, new_maximum):
		return

	var previous_maximum := _maximum_health
	var previous_health := current_health
	var previous_ratio := previous_health / previous_maximum

	_maximum_health = new_maximum

	if not _initialized:
		return

	if preserve_ratio:
		current_health = previous_ratio * _maximum_health
	else:
		current_health = minf(previous_health, _maximum_health)

	maximum_health_changed.emit(_maximum_health, previous_maximum)

	if not is_equal_approx(current_health, previous_health):
		health_changed.emit(current_health, previous_health, _maximum_health)
