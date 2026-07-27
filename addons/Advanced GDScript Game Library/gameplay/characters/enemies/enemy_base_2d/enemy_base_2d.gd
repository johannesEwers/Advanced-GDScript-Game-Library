# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name EnemyBase2D
extends CharacterBody2D
## Base class for two-dimensional enemies.
##
## Health values and health-state transitions are delegated to a
## [HealthComponent]. This class handles enemy-specific movement, animations,
## collision shutdown, and removal from the scene.
##
## The associated [AnimatedSprite2D] should provide the following animations:
## `idle`, `walk_left`, `walk_right`, `turn_left`, `turn_right`, `attack`,
## `hit`, and `death`.
##
## The `walk_left` and `walk_right` animations may loop. The `turn_left`,
## `turn_right`, `attack`, `hit`, and `death` animations must not loop.
## The `attack` animation must contain at least two frames.


## Emitted when this enemy requests that its attack be resolved.
##
## Receiving systems are responsible for creating the attack effect, selecting
## targets, and applying damage. Emission does not mean that an attack has hit.
signal attack_requested(enemy: EnemyBase2D)

## Emitted after this enemy actually loses health.
##
## [param amount] is the health loss applied by the [HealthComponent].
## [param source] identifies the damage source, if one was provided.
signal damage_taken(
	enemy: EnemyBase2D,
	amount: float,
	source: Variant
)

## Emitted when this enemy's health changes from above zero to zero.
##
## [param source] identifies the cause of death, if one was provided.
signal died(
	enemy: EnemyBase2D,
	source: Variant
)


## True while the death animation and removal sequence are running.
##
## This is distinct from [member HealthComponent.is_dead], which represents
## only the logical health state.
var is_dying: bool = false


## Sprite used for all base enemy animations.
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

## Main collision shape disabled when the death sequence begins.
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

## Component responsible for health values and health-state transitions.
@onready var health: HealthComponent = $HealthComponent

## Component responsible for stamina values and stamina-state transitions.
@onready var stamina: StaminaComponent = $StaminaComponent

## Component responsible for magicka values and magicka-state transitions.
@onready var magicka: MagickaComponent = $MagickaComponent

## Inventory containing the items currently carried by this enemy.
@onready var inventory: InventoryComponent = %InventoryComponent


func _ready() -> void:
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_health_died)

	animated_sprite.play(&"idle")


func _physics_process(_delta: float) -> void:
	move_and_slide()


## Starts the left-facing walking animation.
##
## This method changes only the animation. Movement is controlled through
## [member CharacterBody2D.velocity].
func walk_left() -> void:
	if health.is_dead or is_dying:
		return

	animated_sprite.play(&"walk_left")


## Plays the non-looping left-turn animation.
##
## The final frame remains visible and acts as the left-facing idle pose.
func turn_left() -> void:
	if health.is_dead or is_dying:
		return

	animated_sprite.play(&"turn_left")
	await animated_sprite.animation_finished


## Starts the right-facing walking animation.
##
## This method changes only the animation. Movement is controlled through
## [member CharacterBody2D.velocity].
func walk_right() -> void:
	if health.is_dead or is_dying:
		return

	animated_sprite.play(&"walk_right")


## Plays the non-looping right-turn animation.
##
## The final frame remains visible and acts as the right-facing idle pose.
func turn_right() -> void:
	if health.is_dead or is_dying:
		return

	animated_sprite.play(&"turn_right")
	await animated_sprite.animation_finished


## Performs the base attack animation.
##
## The first frame transition is treated as the attack's hit moment and emits
## [signal attacked]. The actual damage should be applied by a combat or ability
## component.
func attack() -> void:
	if health.is_dead or is_dying:
		return

	attack_requested.emit(self)


## Applies damage through the associated [HealthComponent].
##
## Returns the amount of health actually lost after clamping and validation.
func take_damage(amount: float, source: Variant = null) -> float:
	return health.take_damage(amount, source)


## Applies healing through the associated [HealthComponent].
##
## Returns the amount of health actually restored.
func heal(amount: float, source: Variant = null) -> float:
	if is_dying:
		return 0.0

	return health.heal(amount, source)


## Causes an explicit death, including while the enemy is invulnerable.
##
## Returns `true` if this call changed the enemy from alive to dead.
func kill(source: Variant = null) -> bool:
	return health.kill(source)


func _on_health_damaged(amount: float, source: Variant) -> void:
	damage_taken.emit(self, amount, source)


func _on_health_died(source: Variant) -> void:
	if is_dying:
		return

	is_dying = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	collision_shape.set_deferred(&"disabled", true)
	
	var loot_entries := inventory.get_entries()

	died.emit(self, source)

	# Delete Enemy
	# Deletes InventoryComponent too after death!
	# Swap and store inventory items separate, if necessary!
	# Maybe Corpse or LootContainer (e.g. inventory.transfer_all_to(corpse.inventory)).
	queue_free()
